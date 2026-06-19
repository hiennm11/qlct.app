import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/category.dart';
import '../../services/voice_input_service.dart';
import 'voice_input_modal.dart';
import 'voice_result.dart';
import 'voice_transcript_parser.dart';

/// Contract ref: docs/specs/voice-input-v2-contract.html §3 + §4
/// ADR-0083: Voice Input v2 — UX Pass + Fuzzy Parser + Realtime STT.
///
/// VoicePhase state machine (§3):
///   idle → listening → grace → closing → idle
///                  ↓           ↑
///                  └── closing ←┘ (manual stop / hard cap / empty)
///
///   listening: STT đang listen, modal mở, realtime partial + amplitude bar.
///   grace: STT emit finalResult, 800ms buffer chờ user nói tiếp. Mỗi partial
///          mới trong grace reset graceTimer (pause-and-resume pattern).
///   closing: _closeAndApply() đang chạy (parse + Navigator.pop). Không
///          cho user tương tác thêm.
///   error: init fail (4-tier exhausted) hoặc permission denied — modal
///          KHÔNG mở, chỉ show snackbar. Phase reset về idle ngay.
///
/// Pure orchestration: no business logic, no global state. Caller provides
/// the [categories] list (parser is pure, not coupled to `Category.predefined`).
class VoiceCoordinator extends StatefulWidget {
  /// Invoked with the parsed result. [result.amount] or [result.category]
  /// may be null if the parser could not extract them. Caller (e.g.
  /// SuperInputCard) fills NoteEntry + amount + category dropdown, user bấm
  /// Lưu chung (ADR-0069 no-auto-save pattern).
  final void Function(VoiceResult result) onResult;

  /// Categories used by the parser for phrase matching.
  final List<Category> categories;

  /// Optional injected service for testing. Defaults to a new [VoiceInputService].
  final VoiceInputService? voiceService;

  /// The widget below this in the tree (typically a mic button or icon).
  final Widget child;

  const VoiceCoordinator({
    super.key,
    required this.onResult,
    required this.categories,
    required this.child,
    this.voiceService,
  });

  @override
  State<VoiceCoordinator> createState() => _VoiceCoordinatorState();
}

/// State machine cho voice input flow (ADR-0083 §3).
/// Public để [VoiceInputModal] đọc phase render UI phù hợp.
enum VoicePhase { idle, listening, grace, closing, error }

/// Immutable snapshot của coordinator state. Modal rebuild via
/// ValueListenableBuilder khi STT emit (showDialog route không tự rebuild
/// từ parent setState).
class VoiceState {
  final VoicePhase phase;
  final String transcript;
  final double soundLevel;
  const VoiceState({
    required this.phase,
    required this.transcript,
    required this.soundLevel,
  });

  VoiceState copyWith({
    VoicePhase? phase,
    String? transcript,
    double? soundLevel,
  }) {
    return VoiceState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      soundLevel: soundLevel ?? this.soundLevel,
    );
  }
}

class _VoiceCoordinatorState extends State<VoiceCoordinator> {
  late final VoiceInputService _voiceService;
  VoicePhase _phase = VoicePhase.idle;
  String _transcript = '';
  double _soundLevel = 0.0;

  /// Live state stream cho modal — modal rebuild via ListenableBuilder mỗi
  /// khi STT emit partial/final/soundLevel. Nếu chỉ dùng setState thì modal
  /// trong showDialog route KHÔNG rebuild (route giữ content cũ).
  final ValueNotifier<VoiceState> _stateNotifier = ValueNotifier(
    const VoiceState(phase: VoicePhase.idle, transcript: '', soundLevel: 0.0),
  );

  /// 800ms grace buffer cho pause-and-resume (Q2-A). Reset mỗi khi có
  /// partial mới trong grace phase.
  Timer? _graceTimer;

  /// 15s hard cap (Q1 safety). Force _closeAndApply kể cả khi STT bị stuck.
  Timer? _hardCapTimer;

  /// Dialog context key — dùng để Navigator.pop modal an toàn (không pop
  /// nhầm dialog khác khi test pump chain).
  BuildContext? _modalContext;

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceInputService();
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _hardCapTimer?.cancel();
    _voiceService.dispose();
    _stateNotifier.dispose();
    super.dispose();
  }

  /// Push state snapshot ra notifier (modal rebuild qua ListenableBuilder).
  /// Đặt sau setState để đảm bảo state đã commit.
  void _pushState({VoicePhase? phase, String? transcript, double? soundLevel}) {
    _stateNotifier.value = _stateNotifier.value.copyWith(
      phase: phase,
      transcript: transcript,
      soundLevel: soundLevel,
    );
  }

  void _onChildTap() {
    if (_phase != VoicePhase.idle) return; // Debounce — bỏ qua tap trong khi đang nghe.
    _startVoiceInput();
  }

  Future<void> _startVoiceInput() async {
    setState(() {
      _phase = VoicePhase.listening;
      _transcript = '';
      _soundLevel = 0.0;
    });
    _pushState(phase: _phase, transcript: '', soundLevel: 0.0);

    // Show modal NGAY (state=idle transcript). Coordinator sẽ update transcript
    // realtime từ STT callback.
    _showVoiceModal();

    // Arm hard cap 15s trước khi start STT — nếu init fail, cancel ngay.
    _hardCapTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && (_phase == VoicePhase.listening || _phase == VoicePhase.grace)) {
        _closeAndApply();
      }
    });

    await _voiceService.startListening(
      onPartialResult: (t) {
        if (!mounted) return;
        setState(() {
          _transcript = t;
          // Partial mới trong grace phase → reset graceTimer (pause-and-resume).
          if (_phase == VoicePhase.grace) {
            _graceTimer?.cancel();
            _graceTimer = Timer(const Duration(milliseconds: 800), _closeAndApply);
          }
        });
        _pushState(transcript: t);
      },
      onFinalResult: (t) {
        if (!mounted) return;
        setState(() {
          _transcript = t;
          if (_phase == VoicePhase.listening) {
            _phase = VoicePhase.grace;
            _graceTimer = Timer(const Duration(milliseconds: 800), _closeAndApply);
          } else if (_phase == VoicePhase.grace) {
            // FinalResult 2 emit trong grace → close ngay, không chờ timer.
            _closeAndApply();
          }
        });
        _pushState(phase: _phase, transcript: t);
      },
      onSoundLevelChange: (l) {
        if (!mounted) return;
        setState(() {
          // Normalize raw dB (~-2..10) → 0.0-1.0 cho amplitude bars + mic alpha.
          _soundLevel = ((l + 2) / 12).clamp(0.0, 1.0);
        });
        _pushState(soundLevel: _soundLevel);
      },
      onError: (e) {
        if (!mounted) return;
        _showSnackbar(e);
        // Permission denied → CTA "Mở Settings".
        // (Future: detect e == permissionDenied, attach action.)
        if (e.contains('quyền') || e.contains('permission')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              key: const Key('voice-permission-snackbar'),
              content: const Text('Cần quyền truy cập microphone để dùng voice input'),
              action: SnackBarAction(
                label: 'Mở Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        _resetState();
        _popModal();
      },
    );
  }

  void _showVoiceModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        _modalContext = dCtx;
        // ListenableBuilder đảm bảo modal rebuild khi STT emit partial/final/
        // soundLevel. showDialog route không tự rebuild từ parent setState
        // (route giữ content cũ), nên cần notifier + builder.
        return ListenableBuilder(
          listenable: _stateNotifier,
          builder: (ctx, _) {
            final s = _stateNotifier.value;
            return VoiceInputModal(
              phase: s.phase,
              transcript: s.transcript,
              soundLevel: s.soundLevel,
              onStop: _onStopTap,
              onCancel: _onCancelTap,
            );
          },
        );
      },
    ).then((_) {
      // Modal đã pop (qua bất kỳ path nào) — reset context ref.
      _modalContext = null;
    });
  }

  /// Tap mic icon to trong modal (state listening hoặc grace) → force close.
  void _onStopTap() {
    _closeAndApply();
  }

  /// Tap "Hủy bỏ qua" → cancel, KHÔNG fill NoteEntry.
  void _onCancelTap() {
    _graceTimer?.cancel();
    _hardCapTimer?.cancel();
    _voiceService.cancel();
    _resetState();
    _popModal();
  }

  /// Core close logic: parse → fill → close.
  /// Guards: empty transcript → snackbar (không fill), closing in progress
  /// → bail (tránh double-close khi manual stop + graceTimer fire cùng lúc).
  void _closeAndApply() {
    if (_phase == VoicePhase.closing || _phase == VoicePhase.idle) return;
    setState(() => _phase = VoicePhase.closing);
    _pushState(phase: _phase);
    _graceTimer?.cancel();
    _hardCapTimer?.cancel();
    _voiceService.stopListening();

    final t = _transcript.trim();
    if (t.isEmpty) {
      _showSnackbar('Không nhận diện được giọng nói, thử lại');
      _resetState();
      _popModal();
      return;
    }

    final result = parseVoiceTranscript(t, widget.categories);
    widget.onResult(result);
    _resetState();
    _popModal();
  }

  void _popModal() {
    // Try modal context first (precise — không pop nhầm route khác).
    // Fallback outer context nếu _modalContext chưa set (race với error
    // callback fire ngay khi startListening, trước khi showDialog build).
    final ctx = _modalContext ?? context;
    if (Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop();
    }
  }

  void _resetState() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _hardCapTimer?.cancel();
    _hardCapTimer = null;
    if (mounted) {
      setState(() {
        _phase = VoicePhase.idle;
        _transcript = '';
        _soundLevel = 0.0;
      });
    } else {
      _phase = VoicePhase.idle;
      _transcript = '';
      _soundLevel = 0.0;
    }
    _pushState(phase: _phase, transcript: '', soundLevel: 0.0);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @visibleForTesting
  VoicePhase get phase => _phase;
  @visibleForTesting
  String get transcript => _transcript;
  @visibleForTesting
  double get soundLevel => _soundLevel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onChildTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

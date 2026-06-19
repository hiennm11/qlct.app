import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'voice_coordinator.dart' show VoicePhase;

/// Contract ref: docs/specs/voice-input-v2-contract.html §2 + §4
/// ADR-0083: Voice Input v2 — UX Pass + Fuzzy Parser + Realtime STT.
///
/// Modal redesign: mic icon to 96×96 (tap = stop) + 5 amplitude bars realtime
/// + chip preview realtime. Bỏ "Xác nhận" button (ADR-0069 no-auto-save —
/// voice path fill NoteEntry, user bấm Lưu chung ở SuperInputCard).
///
/// Phases (binding từ coordinator):
///   - idle: không render modal (coordinator không showDialog khi idle).
///   - listening: mic primary color, amplitude bars animate, chip preview
///     realtime (partial text từ STT, hoặc "Đang nghe..." nếu empty).
///   - grace: mic primary + check icon, chip xanh đậm (commit cảm giác).
///     graceTimer 800ms sau khi finalResult emit. Mỗi partial mới reset timer.
///   - closing: brief moment khi parse + fill đang chạy, modal pop ngay.
class VoiceInputModal extends StatelessWidget {
  final VoicePhase phase;
  final String transcript;
  final double soundLevel;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const VoiceInputModal({
    required this.phase,
    required this.transcript,
    required this.soundLevel,
    required this.onStop,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isGrace = phase == VoicePhase.grace;
    final hasTranscript = transcript.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      child: Dialog(
        key: const Key('voice-modal'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    size: 24,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Ghi chép bằng giọng nói',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Mic icon to 96×96 — tap = stop
              // Container để size 96×96 ổn định, button overlay cho hit target.
              SizedBox(
                width: 96,
                height: 96,
                child: Material(
                  key: const Key('voice-modal-mic-circle'),
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('voice-modal-mic-stop'),
                    customBorder: const CircleBorder(),
                    onTap: onStop,
                    child: Center(
                      child: Icon(
                        isGrace ? Icons.check : Icons.mic,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5 amplitude bars — height mô phỏng _soundLevel (0.0-1.0).
              // Bar giữa cao nhất, 2 bên thấp dần. Multiplier 4/14/24/14/4 là
              // mô phỏng spec §2 listening state; animate bằng Tween.
              _AmplitudeBars(soundLevel: soundLevel),
              const SizedBox(height: 20),

              // Chip preview realtime — empty → hint "Đang nghe..."; grace →
              // solid primary background + check; listening → primary-soft
              // background với transcript text.
              _ChipPreview(
                transcript: transcript,
                isGrace: isGrace,
                hasTranscript: hasTranscript,
              ),
              const SizedBox(height: 16),

              // Cancel button — text only, gray secondary.
              TextButton(
                key: const Key('voice-modal-cancel'),
                onPressed: onCancel,
                child: const Text('Hủy bỏ qua'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmplitudeBars extends StatelessWidget {
  final double soundLevel;
  const _AmplitudeBars({required this.soundLevel});

  @override
  Widget build(BuildContext context) {
    // Spec §2 listening state: 5 bars heights 4/14/24/14/4 px. Scale mỗi
    // bar theo soundLevel (0.0-1.0) để có animation realtime. Bar giữa
    // (index 2) cao nhất, 2 bên thấp dần.
    const baseHeights = [4.0, 14.0, 24.0, 14.0, 4.0];
    final minH = 4.0;
    return SizedBox(
      key: const Key('voice-modal-amplitude-bars'),
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (i) {
          // Sound level scale: 0.0 = minH, 1.0 = baseHeights[i].
          final h = minH + (baseHeights[i] - minH) * (0.3 + 0.7 * soundLevel);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 6,
              height: h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChipPreview extends StatelessWidget {
  final String transcript;
  final bool isGrace;
  final bool hasTranscript;

  const _ChipPreview({
    required this.transcript,
    required this.isGrace,
    required this.hasTranscript,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasTranscript) {
      // Empty hint.
      return Text(
        'Đang nghe...',
        key: const Key('voice-modal-empty-hint'),
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      );
    }

    if (isGrace) {
      // Grace phase: solid primary + check icon, commit cảm giác.
      return Container(
        key: const Key('voice-modal-chip-preview'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              transcript,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Listening phase: primary-soft chip với border.
    return Container(
      key: const Key('voice-modal-chip-preview'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        transcript,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/voice_input_service.dart';
import 'voice_input_modal.dart';
import 'voice_result.dart';
import 'voice_transcript_parser.dart';

/// A coordinator widget that wraps a child (typically a mic button) and
/// owns the full voice input lifecycle: tap → start listening → show modal
/// → parse transcript → invoke [onResult].
///
/// Pure orchestration: no business logic, no global state. Caller provides
/// the [categories] list (parser is pure, not coupled to `Category.predefined`).
class VoiceCoordinator extends StatefulWidget {
  /// Invoked with the parsed result. [result.amount] or [result.category]
  /// may be null if the parser could not extract them.
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

class _VoiceCoordinatorState extends State<VoiceCoordinator> {
  late final VoiceInputService _voiceService;
  bool _isListening = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceInputService();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _onChildTap() {
    _startVoiceInput();
  }

  void _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _transcript = '';
    });
    _showVoiceModal();
    await _voiceService.startListening(
      onResult: (t) {
        if (!mounted) return;
        setState(() {
          _transcript = t;
          _isListening = false;
        });
        Navigator.of(context).pop();
        if (!mounted) return;
        _showVoiceModal();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _transcript = 'Lỗi: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
      },
    );
  }

  void _showVoiceModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => VoiceInputModal(
        isListening: _isListening,
        transcript: _transcript,
        onClose: () {
          _voiceService.stopListening();
          setState(() => _isListening = false);
          Navigator.of(dCtx).pop();
        },
        onCancel: () {
          _voiceService.cancel();
          setState(() {
            _isListening = false;
            _transcript = '';
          });
          Navigator.of(dCtx).pop();
        },
        onConfirm: _handleConfirm,
      ),
    );
  }

  void _handleConfirm(String transcript) {
    final result = parseVoiceTranscript(transcript, widget.categories);
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onChildTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
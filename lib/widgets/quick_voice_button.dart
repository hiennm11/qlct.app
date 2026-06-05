import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../services/voice_input_service.dart';
import '../core/vietnamese_number_parser.dart';
import 'voice_input_modal.dart';

/// Quick voice input button - direct access to voice transcription
class QuickVoiceButton extends StatefulWidget {
  const QuickVoiceButton({super.key});

  @override
  State<QuickVoiceButton> createState() => _QuickVoiceButtonState();
}

class _QuickVoiceButtonState extends State<QuickVoiceButton> {
  final _voiceService = VoiceInputService();
  bool _isListening = false;
  String _transcript = '';

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _transcript = '';
    });

    _showVoiceModal();

    await _voiceService.startListening(
      onResult: (transcript) {
        if (!context.mounted) return;
        setState(() {
          _transcript = transcript;
          _isListening = false;
        });
        // Rebuild modal to show input field with recognized text
        Navigator.of(context).pop();
        if (!context.mounted) return;
        _showVoiceModal();
      },
      onError: (error) {
        if (!context.mounted) return;
        setState(() {
          _isListening = false;
          _transcript = 'Lỗi: $error';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
    );
  }

  void _showVoiceModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoiceInputModal(
        isListening: _isListening,
        transcript: _transcript,
        onClose: () {
          _voiceService.stopListening();
          setState(() => _isListening = false);
          Navigator.of(context).pop();
        },
        onCancel: () {
          _voiceService.cancel();
          setState(() {
            _isListening = false;
            _transcript = '';
          });
          Navigator.of(context).pop();
        },
        onConfirm: (editedTranscript) {
          final viewModel = context.read<ExpenseViewModel>();
          final amount = VietnameseNumberParser.extractAmount(editedTranscript);

          if (amount != null) {
            // Match category using predefined phrases
            String matchedCategory = 'Khác';
            final lowerTranscript = editedTranscript.toLowerCase();

            for (final cat in viewModel.categories) {
              for (final phrase in cat.phrases) {
                if (lowerTranscript.contains(phrase.toLowerCase())) {
                  matchedCategory = cat.name;
                  break;
                }
              }
              if (matchedCategory != 'Khác') break;
            }

            final category = viewModel.categories.firstWhere(
              (c) => c.name == matchedCategory,
            );

            viewModel.addTransaction(
              amount: amount,
              category: category.name,
              note: editedTranscript,
              emoji: category.emoji,
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã thêm giao dịch: $editedTranscript'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không thể nhận diện số tiền từ giọng nói'),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _startVoiceInput,
      icon: const Icon(Icons.mic),
      label: const Text('Ghi chép bằng giọng nói'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

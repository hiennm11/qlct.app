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
        setState(() {
          _transcript = transcript;
          _isListening = false;
        });
        // Rebuild modal to show input field with recognized text
        Navigator.of(context).pop();
        _showVoiceModal();
      },
      onError: (error) {
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
            // Auto-detect category if mentioned
            String? detectedCategory;
            final lowerTranscript = editedTranscript.toLowerCase();
            // Simple category detection - can be enhanced
            if (lowerTranscript.contains('ăn') ||
                lowerTranscript.contains('cơm')) {
              detectedCategory = 'Ăn uống';
            } else if (lowerTranscript.contains('xe') ||
                lowerTranscript.contains('xăng')) {
              detectedCategory = 'Giao thông';
            } else if (lowerTranscript.contains('sách') ||
                lowerTranscript.contains('học')) {
              detectedCategory = 'Giáo dục';
            }

            viewModel.addTransaction(
              amount: amount,
              category: detectedCategory ?? 'Khác',
              note: editedTranscript,
              emoji: ""
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
    return FloatingActionButton(
      onPressed: _startVoiceInput,
      tooltip: 'Ghi chú bằng giọng nói',
      child: const Icon(Icons.mic),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../models/category.dart';
import '../services/voice_input_service.dart';
import '../core/formatters.dart';
import '../core/vietnamese_number_parser.dart';
import 'voice_input_modal.dart';

/// Widget for custom transaction input
class CustomInputWidget extends StatefulWidget {
  const CustomInputWidget({super.key});

  @override
  State<CustomInputWidget> createState() => _CustomInputWidgetState();
}

class _CustomInputWidgetState extends State<CustomInputWidget> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _voiceService = VoiceInputService();
  final _categoryKey = GlobalKey();
  String? _selectedCategory;
  bool _isListening = false;
  String _transcript = '';

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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
        _parseVoiceInput(transcript);
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
          _parseVoiceInput(editedTranscript);
        },
      ),
    );
  }

  void _parseVoiceInput(String transcript) {
    // Extract amount
    final amount = VietnameseNumberParser.extractAmount(transcript);
    if (amount != null) {
      // Format with thousand separators (e.g. 100000 → 100.000)
      _amountController.text = _formatNumber(amount);
    }

    // Try to match category
    String? matchedCategory;
    final lowerTranscript = transcript.toLowerCase();

    for (final cat in Category.predefined) {
      for (final phrase in cat.phrases) {
        if (lowerTranscript.contains(phrase.toLowerCase())) {
          matchedCategory = cat.name;
          break;
        }
      }
      if (matchedCategory != null) break;
    }

    if (matchedCategory != null) {
      setState(() => _selectedCategory = matchedCategory);
    }

    // Set note as the full transcript
    _noteController.text = transcript;
  }

  void _addTransaction() async {
    final amount = int.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }

    final category = Category.predefined.firstWhere(
      (c) => c.name == _selectedCategory,
    );

    final vm = context.read<ExpenseViewModel>();
    try {
      await vm.addTransaction(
        amount: amount,
        category: category.name,
        emoji: category.emoji,
        note: _noteController.text,
      );

      _amountController.clear();
      _noteController.clear();
      setState(() {
        _selectedCategory = null;
      });

      if (!context.mounted) return;
      if (vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm giao dịch'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Format raw number with thousand separators (e.g. 100000 → 100.000)
  String _formatNumber(int number) {
    final digits = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✎ Ghi chép tự do',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Số tiền',
                hintText: 'Nhập số tiền',
                prefixText: '₫ ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandSeparatorFormatter()],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              key: _categoryKey,
              onTap: () {
                final RenderBox box = _categoryKey.currentContext!.findRenderObject() as RenderBox;
                final Offset offset = box.localToGlobal(Offset.zero);
                showMenu<String>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    offset.dx,
                    offset.dy + box.size.height,
                    offset.dx + box.size.width,
                    offset.dy + box.size.height,
                  ),
                  items: Category.predefined.map((cat) {
                    return PopupMenuItem<String>(
                      value: cat.name,
                      child: Row(
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(cat.name),
                        ],
                      ),
                    );
                  }).toList(),
                ).then((selected) {
                  if (selected != null && mounted) {
                    setState(() => _selectedCategory = selected);
                  }
                });
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  hintText: 'Chọn danh mục',
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _selectedCategory != null
                      ? _selectedCategory!
                      : 'Chọn danh mục',
                  style: TextStyle(
                    color: _selectedCategory != null ? null : Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                hintText: 'Nhập ghi chú',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addTransaction,
                    child: const Text('Thêm giao dịch'),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _startVoiceInput,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: const Icon(Icons.mic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/transaction_suggestion_engine.dart';
import '../services/voice_input_service.dart';
import '../core/vietnamese_number_parser.dart';
import 'voice/voice_input_modal.dart';

/// Widget for quick transaction input with category sliders
class QuickInputWidget extends StatefulWidget {
  const QuickInputWidget({super.key});

  @override
  State<QuickInputWidget> createState() => _QuickInputWidgetState();
}

class _QuickInputWidgetState extends State<QuickInputWidget> {
  final Map<String, double> _amounts = {};
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Use seed categories as the initial amount preset so slider defaults
    // exist even before CategoryViewModel has loaded. Real values are
    // reconciled on first build.
    for (final category in seedCategories) {
      _amounts[category.name] = category.quickAmountDefault.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expandable header
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '⚡ Ghi chép nhanh',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            // Expandable content
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (ctx) {
                  final cats = ctx.watch<CategoryViewModel>().quickInputCategories;
                  if (cats.isEmpty) return const SizedBox.shrink();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cats.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = cats[index];
                      return _CategoryCard(
                    category: category,
                    amount: _amounts[category.name]!,
                    onAmountChanged: (value) {
                      setState(() {
                        _amounts[category.name] = value;
                      });
                    },
                    onAdd: () async {
                      final vm = context.read<ExpenseViewModel>();
                      try {
                        await vm.addTransaction(
                          amount: _amounts[category.name]!.toInt(),
                          category: category.name,
                          emoji: category.emoji,
                        );
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
                            SnackBar(
                              content: Text(
                                'Đã thêm ${CurrencyFormatter.format(_amounts[category.name]!.toInt())} - ${category.name}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        debugPrint('Error quick input add: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    onVoiceInput: (transcript) async {
                      final vm = context.read<ExpenseViewModel>();
                      final amount = VietnameseNumberParser.extractAmount(
                        transcript,
                      );
                      if (amount != null) {
                        setState(() {
                          _amounts[category.name] = amount.toDouble();
                        });
                        try {
                          await vm.addTransaction(
                            amount: amount,
                            category: category.name,
                            emoji: category.emoji,
                            note: transcript,
                          );
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
                              SnackBar(
                                content: Text(
                                  'Đã thêm ${CurrencyFormatter.format(amount)} - ${category.name}',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          debugPrint('Error quick input voice: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Không thể nhận diện số tiền từ giọng nói'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final Category category;
  final double amount;
  final ValueChanged<double> onAmountChanged;
  final VoidCallback onAdd;
  final ValueChanged<String> onVoiceInput;

  const _CategoryCard({
    required this.category,
    required this.amount,
    required this.onAmountChanged,
    required this.onAdd,
    required this.onVoiceInput,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
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
          final amount = VietnameseNumberParser.extractAmount(editedTranscript);
          if (amount != null) {
            widget.onVoiceInput(editedTranscript);
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: widget.amount,
                min: widget.category.quickAmountMin.toDouble(),
                max: widget.category.quickAmountMax.toDouble(),
                onChanged: (value) {
                  // Round to nearest 1000
                  final rounded = (value / 1000).round() * 1000.0;
                  widget.onAmountChanged(rounded);
                },
                activeColor: AppColors.primary,
              ),
            ),
            Text(
              CurrencyFormatter.format(widget.amount.toInt()),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            _buildAmountSuggestionChips(context),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onAdd,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Thêm'),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: _startVoiceInput,
                    icon: const Icon(Icons.mic, size: 16),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build compact amount suggestion chips for this category.
  /// No note chips (quick input add path has no note except voice).
  /// Only shows chips if engine returns amounts; label is tiny to avoid clutter.
  Widget _buildAmountSuggestionChips(BuildContext context) {
    final expenseVM = context.watch<ExpenseViewModel>();
    final engine = TransactionSuggestionEngine();
    final List<Transaction> recent = expenseVM.allTransactions;
    final amounts = engine.getSuggestedAmounts(widget.category, recent);
    if (amounts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: amounts.map((a) {
        return ActionChip(
          label: Text(
            ThousandSeparatorFormatter.formatValue(a),
            style: const TextStyle(fontSize: 10),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          onPressed: () {
            widget.onAmountChanged(a.toDouble());
          },
        );
      }).toList(),
    );
  }
}

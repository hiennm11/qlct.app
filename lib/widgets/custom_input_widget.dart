import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../models/transaction.dart';
import '../core/formatters.dart';
import '../services/transaction_suggestion_engine.dart';
import 'voice/voice_coordinator.dart';
import 'voice/voice_result.dart';

/// Widget for custom transaction input
class CustomInputWidget extends StatefulWidget {
  const CustomInputWidget({super.key});

  @override
  State<CustomInputWidget> createState() => _CustomInputWidgetState();
}

class _CustomInputWidgetState extends State<CustomInputWidget> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _categoryKey = GlobalKey();
  String? _selectedCategory;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onVoiceResult(VoiceResult result) {
    // Pre-fill amount
    if (result.amount != null) {
      _amountController.text = _formatNumber(result.amount!);
    }
    // Pre-fill category
    if (result.category != null) {
      setState(() => _selectedCategory = result.category!.name);
    }
    // Set note to transcript
    _noteController.text = result.transcript;
  }

  void _addTransaction() async {
    final amount = int.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn danh mục'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final category = context.read<CategoryViewModel>().categoryByName(_selectedCategory!)!;

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
      debugPrint('Error custom input add: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
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
                  items: context.read<CategoryViewModel>().quickInputCategories.map((cat) {
                    return PopupMenuItem<String>(
                      value: cat.name,
                      child: Row(
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          // Constrain long category names ("Nhà (Điện, nước, wifi)")
                          // so the menu doesn't overflow PopupMenu's default
                          // 304px max width on narrow surfaces.
                          Flexible(
                            child: Text(
                              cat.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
            if (_selectedCategory != null) _buildSuggestionChips(context),
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
                VoiceCoordinator(
                  onResult: _onVoiceResult,
                  categories: context.watch<CategoryViewModel>().quickInputCategories,
                  child: FloatingActionButton(
                    onPressed: () {}, // actual tap handled by coordinator
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: const Icon(Icons.mic),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build suggestion chips for amount + note based on selected category.
  /// Tapping a chip autofills the field; no auto-submit.
  Widget _buildSuggestionChips(BuildContext context) {
    final expenseVM = context.watch<ExpenseViewModel>();
    final category = context.read<CategoryViewModel>().categoryByName(_selectedCategory!) ??
        context.read<CategoryViewModel>().activeCategories.first;
    final engine = TransactionSuggestionEngine();
    final List<Transaction> recent = expenseVM.allTransactions;
    final amounts = engine.getSuggestedAmounts(category, recent);
    final notes = engine.getSuggestedNotes(category, recent);

    if (amounts.isEmpty && notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (amounts.isNotEmpty) ...[
          Text(
            'Gợi ý số tiền',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: amounts.map((a) {
              return ActionChip(
                label: Text(ThousandSeparatorFormatter.formatValue(a)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  _amountController.text =
                      ThousandSeparatorFormatter.formatValue(a);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (notes.isNotEmpty) ...[
          Text(
            'Gợi ý ghi chú',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: notes.map((n) {
              return ActionChip(
                label: Text(
                  n,
                  overflow: TextOverflow.ellipsis,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  _noteController.text = n;
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

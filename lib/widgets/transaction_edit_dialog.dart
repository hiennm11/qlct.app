import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/transaction_suggestion_engine.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';

/// Dialog for editing an existing transaction
class _TransactionEditDialog extends StatefulWidget {
  final Transaction transaction;
  /// Optional ExpenseViewModel for suggestion chips.
  /// When provided, suggestion chips are shown.
  /// When null, chips are hidden (e.g. in tests without provider).
  final ExpenseViewModel? expenseViewModel;

  const _TransactionEditDialog({
    required this.transaction,
    this.expenseViewModel,
  });

  @override
  State<_TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<_TransactionEditDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late String _selectedCategory;
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
    _selectedDate = widget.transaction.date;
    _amountController.text =
        ThousandSeparatorFormatter.formatValue(widget.transaction.amount);
    _noteController.text = widget.transaction.note;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Build suggestion chips for amount + note based on selected category.
  /// Filters out the current transaction so it doesn't suggest its own data.
  /// Tapping a chip overrides the respective field value; no auto-submit.
  /// Uses ListenableBuilder so chips rebuild when view model notifies.
  Widget _buildSuggestionChips(BuildContext context) {
    final expenseVM = widget.expenseViewModel;
    if (expenseVM == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: expenseVM,
      builder: (context, _) {
        final catVM = Provider.of<CategoryViewModel>(context, listen: false);
        Category? found = catVM.categoryByName(_selectedCategory);
        if (found == null) {
          if (catVM.activeCategories.isNotEmpty) {
            found = catVM.activeCategories.first;
          } else {
            found = seedCategories.first;
          }
        }
        final category = found;
        final engine = TransactionSuggestionEngine();
        // Filter out current transaction so suggestions come from other history.
        final List<Transaction> recent = expenseVM.allTransactions
            .where((t) => t.id != widget.transaction.id)
            .toList();
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
                      setState(() {
                        _amountController.text =
                            ThousandSeparatorFormatter.formatValue(a);
                      });
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
                      setState(() {
                        _noteController.text = n;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = ThousandSeparatorFormatter.strip(_amountController.text);
    final parsedAmount = int.parse(rawAmount);

    final category = Provider.of<CategoryViewModel>(context, listen: false)
        .categoryByName(_selectedCategory)!;

    final updated = Transaction(
      id: widget.transaction.id,
      amount: parsedAmount,
      category: _selectedCategory,
      emoji: category.emoji,
      note: _noteController.text.trim(),
      date: _selectedDate,
      sourceRecurringId: widget.transaction.sourceRecurringId,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa giao dịch'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              Consumer<CategoryViewModel>(
                builder: (context, catVM, _) {
                  final cats = catVM.quickInputCategories.isNotEmpty
                      ? catVM.quickInputCategories
                      : seedCategories;
                  return DropdownButtonFormField<String>(
                    initialValue: cats.any((c) => c.name == _selectedCategory)
                        ? _selectedCategory
                        : cats.first.name,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: cats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.name,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(c.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn danh mục' : null,
                  );
                },
              ),
              // Recurring source info label
              if (widget.transaction.sourceRecurringId != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.loop, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Giao dịch này được tạo tự động từ định kỳ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _buildSuggestionChips(context),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VNĐ)',
                  suffixText: 'đ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandSeparatorFormatter()],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập số tiền';
                  final amount = int.tryParse(
                    ThousandSeparatorFormatter.strip(v),
                  );
                  if (amount == null || amount <= 0) {
                    return 'Số tiền phải lớn hơn 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date picker row
              Row(
                children: [
                  const Text('Ngày: '),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormatter.formatDate(_selectedDate)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

/// Show the transaction edit dialog and return the updated transaction.
/// Pass [expenseViewModel] to enable suggestion chips. When null, chips
/// are hidden (e.g. when calling context doesn't have a Provider).
Future<Transaction?> showTransactionEditDialog(
  BuildContext context,
  Transaction transaction, {
  ExpenseViewModel? expenseViewModel,
  CategoryViewModel? categoryViewModel,
}) {
  // Resolve view model from context if not passed explicitly.
  // Use try-catch because the dialog's new route does not inherit
  // the provider from the caller's context tree.
  ExpenseViewModel? vm = expenseViewModel;
  if (vm == null) {
    try {
      vm = Provider.of<ExpenseViewModel>(context, listen: false);
    } catch (_) {
      vm = null;
    }
  }
  CategoryViewModel? catVM = categoryViewModel;
  if (catVM == null) {
    try {
      catVM = Provider.of<CategoryViewModel>(context, listen: false);
    } catch (_) {
      catVM = null;
    }
  }
  return showDialog<Transaction>(
    context: context,
    builder: (dialogContext) {
      if (catVM != null) {
        return ChangeNotifierProvider<CategoryViewModel>.value(
          value: catVM,
          child: _TransactionEditDialog(
            transaction: transaction,
            expenseViewModel: vm,
          ),
        );
      }
      return _TransactionEditDialog(
        transaction: transaction,
        expenseViewModel: vm,
      );
    },
  );
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../core/formatters.dart';
import '../services/transaction_suggestion_engine.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';

class RecurringEditDialog extends StatefulWidget {
  final RecurringTransaction? existing; // null = add mode
  /// Optional ExpenseViewModel for suggestion chips.
  /// When provided, chips are shown. When null, chips are hidden.
  final ExpenseViewModel? expenseViewModel;
  final CategoryViewModel? categoryViewModel;

  const RecurringEditDialog({
    super.key,
    this.existing,
    this.expenseViewModel,
    this.categoryViewModel,
  });

  static Future<RecurringEditResult?> show(
    BuildContext context, {
    RecurringTransaction? existing,
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
    return showDialog<RecurringEditResult>(
      context: context,
      builder: (_) {
        if (catVM != null) {
          return ChangeNotifierProvider<CategoryViewModel>.value(
            value: catVM,
            child: RecurringEditDialog(
              existing: existing,
              expenseViewModel: vm,
              categoryViewModel: catVM,
            ),
          );
        }
        return RecurringEditDialog(
          existing: existing,
          expenseViewModel: vm,
        );
      },
    );
  }

  @override
  State<RecurringEditDialog> createState() => _RecurringEditDialogState();
}

class RecurringEditResult {
  final String categoryName;
  final int amount;
  final String note;
  final String frequency;
  final DateTime startDate;
  final String? id; // null for new, existing id for edit

  const RecurringEditResult({
    required this.categoryName,
    required this.amount,
    this.note = '',
    required this.frequency,
    required this.startDate,
    this.id,
  });
}

class _RecurringEditDialogState extends State<RecurringEditDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Ăn ngoài'; // fallback; actual value set from VM if available
  String _selectedFrequency = 'daily';
  DateTime _startDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedCategory = existing.categoryName;
      _amountController.text = ThousandSeparatorFormatter.formatValue(existing.amount);
      _noteController.text = existing.note;
      _selectedFrequency = existing.frequency;
      _startDate = existing.nextRunAt;
    } else {
      // Use persisted catalog if available, fallback to legacy.
      try {
        final vm = Provider.of<CategoryViewModel>(context, listen: false);
        if (vm.quickInputCategories.isNotEmpty) {
          _selectedCategory = vm.quickInputCategories.first.name;
        }
      } catch (_) {
        _selectedCategory = Category.predefined.first.name;
      }
    }
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
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  /// Build suggestion chips for amount + note based on selected category.
  /// Tapping a chip autofills the field; no auto-submit.
  /// Uses ListenableBuilder so chips rebuild when view model notifies.
  /// Returns empty if no view model is provided.
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
            found = Category.predefined.first;
          }
        }
        final category = found;
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final dateStr = '${_startDate.day}/${_startDate.month}/${_startDate.year}';

    return AlertDialog(
      title: Text(isEdit ? 'Sửa giao dịch định kỳ' : 'Thêm giao dịch định kỳ'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category
              Consumer<CategoryViewModel>(
                builder: (context, catVM, _) {
                  final cats = catVM.quickInputCategories.isNotEmpty
                      ? catVM.quickInputCategories
                      : Category.predefined;
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
                                Text(
                                  c.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
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
                    return 'Số tiền không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Frequency
              const Text(
                'Tần suất',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Ngày')),
                  ButtonSegment(value: 'weekly', label: Text('Tuần')),
                  ButtonSegment(value: 'monthly', label: Text('Tháng')),
                ],
                selected: {_selectedFrequency},
                onSelectionChanged: (v) =>
                    setState(() => _selectedFrequency = v.first),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                ),
              ),
              const SizedBox(height: 12),

              // Start date
              Row(
                children: [
                  Text(isEdit ? 'Ngày chạy kế tiếp: ' : 'Bắt đầu: '),
                  TextButton(onPressed: _pickDate, child: Text(dateStr)),
                ],
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final amount = int.parse(
              ThousandSeparatorFormatter.strip(_amountController.text),
            );
            Navigator.pop(
              context,
              RecurringEditResult(
                id: widget.existing?.id,
                categoryName: _selectedCategory,
                amount: amount,
                note: _noteController.text,
                frequency: _selectedFrequency,
                startDate: _startDate,
              ),
            );
          },
          child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
        ),
      ],
    );
  }
}

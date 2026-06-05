import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Dialog for editing an existing transaction
class _TransactionEditDialog extends StatefulWidget {
  final Transaction transaction;

  const _TransactionEditDialog({required this.transaction});

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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = ThousandSeparatorFormatter.strip(_amountController.text);
    final parsedAmount = int.parse(rawAmount);

    final category = Category.predefined.firstWhere(
      (c) => c.name == _selectedCategory,
    );

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
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: Category.predefined
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.name,
                        child: Row(
                          children: [
                            Text(c.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                validator: (v) =>
                    v == null ? 'Vui lòng chọn danh mục' : null,
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
              const SizedBox(height: 16),

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

/// Show the transaction edit dialog and return the updated transaction
Future<Transaction?> showTransactionEditDialog(
  BuildContext context,
  Transaction transaction,
) {
  return showDialog<Transaction>(
    context: context,
    builder: (context) =>
        _TransactionEditDialog(transaction: transaction),
  );
}
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../core/formatters.dart';

class RecurringEditDialog extends StatefulWidget {
  final RecurringTransaction? existing; // null = add mode

  const RecurringEditDialog({super.key, this.existing});

  static Future<RecurringEditResult?> show(
    BuildContext context, {
    RecurringTransaction? existing,
  }) {
    return showDialog<RecurringEditResult>(
      context: context,
      builder: (_) => RecurringEditDialog(existing: existing),
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
  String _selectedCategory = Category.predefined.first.name;
  String _selectedFrequency = 'daily';
  DateTime _startDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  String _formatAmount(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedCategory = existing.categoryName;
      _amountController.text = _formatAmount(existing.amount);
      _noteController.text = existing.note;
      _selectedFrequency = existing.frequency;
      _startDate = existing.nextRunAt;
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
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: Category.predefined
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.name,
                        child: Row(
                          children: [
                            Text(
                              c.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
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
                  const Text('Bắt đầu: '),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/budget_viewmodel.dart';
import '../models/category.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Show budget edit dialog
Future<void> showBudgetEditDialog(
  BuildContext context, {
  String? categoryName,
  int? currentLimit,
  int? currentThreshold,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _BudgetEditDialog(
      categoryName: categoryName,
      currentLimit: currentLimit,
      currentThreshold: currentThreshold,
    ),
  );
}

class _BudgetEditDialog extends StatefulWidget {
  final String? categoryName;
  final int? currentLimit;
  final int? currentThreshold;

  const _BudgetEditDialog({
    this.categoryName,
    this.currentLimit,
    this.currentThreshold,
  });

  @override
  State<_BudgetEditDialog> createState() => _BudgetEditDialogState();
}

class _BudgetEditDialogState extends State<_BudgetEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  late String? _selectedCategory;
  late int _threshold;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categoryName;
    _threshold = widget.currentThreshold ?? 80;
    if (widget.currentLimit != null && widget.currentLimit! > 0) {
      _limitController.text = widget.currentLimit.toString();
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }

    final limit = int.tryParse(_limitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hạn mức phải lớn hơn 0')),
      );
      return;
    }

    await context.read<BudgetViewModel>().setBudget(
          _selectedCategory!,
          limit,
          _threshold,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.categoryName != null;
    // Get categories that don't have a budget yet (only when adding new)
    final availableCategories = Category.predefined;

    return AlertDialog(
      title: Text(isEditing ? 'Sửa ngân sách' : 'Thêm ngân sách'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEditing) ...[
                const Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    hintText: 'Chọn danh mục',
                  ),
                  items: availableCategories
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Row(
                              children: [
                                Text(c.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                  validator: (value) => value == null ? 'Vui lòng chọn danh mục' : null,
                ),
                const SizedBox(height: 16),
              ] else
                Row(
                  children: [
                    Text(
                      Category.predefined
                          .firstWhere(
                            (c) => c.name == widget.categoryName,
                            orElse: () => const Category(
                              name: '',
                              emoji: '📌',
                              minAmount: 0,
                              defaultAmount: 0,
                              maxAmount: 0,
                              phrases: [],
                            ),
                          )
                          .emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.categoryName!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Text('Hạn mức tháng', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Nhập số tiền',
                  suffixText: 'đ',
                ),
                onChanged: (value) {
                  // Format the displayed text as user types
                  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isNotEmpty) {
                    final formatted = CurrencyFormatter.format(int.parse(digits));
                    if (formatted != _limitController.text) {
                      _limitController.value = TextEditingValue(
                        text: digits,
                        selection: TextSelection.collapsed(offset: digits.length),
                      );
                    }
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập hạn mức';
                  final limit = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  if (limit <= 0) return 'Hạn mức phải lớn hơn 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ngưỡng cảnh báo', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '$_threshold%',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _threshold.toDouble(),
                min: 50,
                max: 100,
                divisions: 10,
                label: '$_threshold%',
                onChanged: (value) => setState(() => _threshold = value.round()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
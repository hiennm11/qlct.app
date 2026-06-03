import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../viewmodels/budget_viewmodel.dart';

/// Show budget bulk edit dialog
Future<void> showBudgetBulkEditDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const BudgetBulkEditDialog(),
  );
}

class BudgetBulkEditDialog extends StatefulWidget {
  const BudgetBulkEditDialog({super.key});

  @override
  State<BudgetBulkEditDialog> createState() => _BudgetBulkEditDialogState();
}

class _BudgetBulkEditDialogState extends State<BudgetBulkEditDialog> {
  final _totalController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadExistingValues();
  }

  void _initControllers() {
    for (final category in Category.predefined) {
      _categoryControllers[category.name] = TextEditingController();
    }
  }

  void _loadExistingValues() {
    final viewModel = context.read<BudgetViewModel>();
    
    if (viewModel.totalBudget != null) {
      _totalController.text = viewModel.totalBudget.toString();
    }
    
    for (final budget in viewModel.budgets) {
      final controller = _categoryControllers[budget.categoryName];
      if (controller != null && budget.monthlyLimit > 0) {
        controller.text = budget.monthlyLimit.toString();
      }
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (final controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _getTotalAmount() {
    final text = _totalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(text) ?? 0;
  }

  int _getAllocatedAmount() {
    int total = 0;
    for (final controller in _categoryControllers.values) {
      final text = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
      total += int.tryParse(text) ?? 0;
    }
    return total;
  }

  int _getRemainingAmount() {
    return _getTotalAmount() - _getAllocatedAmount();
  }

  bool _isOverAllocated() {
    return _getAllocatedAmount() > _getTotalAmount() && _getTotalAmount() > 0;
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    final viewModel = context.read<BudgetViewModel>();
    final total = _getTotalAmount();

    // Save total budget
    await viewModel.setTotalBudget(total);

    // Build list of budgets with limits > 0
    final budgets = <Budget>[];
    for (final category in Category.predefined) {
      final controller = _categoryControllers[category.name]!;
      final text = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
      final limit = int.tryParse(text) ?? 0;
      
      if (limit > 0) {
        final existingBudget = viewModel.budgets.firstWhere(
          (b) => b.categoryName == category.name,
          orElse: () => Budget(
            id: const Uuid().v4(),
            categoryName: category.name,
            monthlyLimit: limit,
            alertThreshold: 80,
            createdAt: DateTime.now(),
          ),
        );
        budgets.add(Budget(
          id: existingBudget.id,
          categoryName: category.name,
          monthlyLimit: limit,
          alertThreshold: 80,
          createdAt: existingBudget.createdAt,
        ));
      }
    }

    await viewModel.setAllBudgets(budgets);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allocated = _getAllocatedAmount();
    final remaining = _getRemainingAmount();
    final isOverAllocated = _isOverAllocated();

    return AlertDialog(
      title: Row(
        children: [
          const Text('Thiet Lap Ngan Sach'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total budget section
              const Text(
                'Tong Ngan Sach Thang',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandSeparatorFormatter()],
                decoration: const InputDecoration(
                  hintText: 'Nhap so tien',
                  prefixText: '\u20ab ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverAllocated ? AppColors.error.withValues(alpha: 0.1) : AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Da phan bo:'),
                        Text(
                          CurrencyFormatter.format(allocated),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isOverAllocated ? AppColors.error : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Con lai:'),
                        Text(
                          CurrencyFormatter.format(remaining),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isOverAllocated ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    if (isOverAllocated) ...[
                      const SizedBox(height: 8),
                      Text(
                        'So tien phan bo vuot qua tong ngan sach!',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category limits
              const Text(
                'Han Muc Theo Danh Muc',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...Category.predefined.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(category.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.name,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _categoryControllers[category.name],
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandSeparatorFormatter()],
                          decoration: const InputDecoration(
                            hintText: '0',
                            prefixText: '\u20ab ',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Huy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Luu'),
        ),
      ],
    );
  }
}
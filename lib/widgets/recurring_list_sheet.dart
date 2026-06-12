import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../viewmodels/recurring_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import 'recurring_edit_dialog.dart';

/// Full recurring transactions list bottom sheet.
/// Shows ALL rules with swipe-to-delete and tap-to-edit.
class RecurringListSheet extends StatelessWidget {
  const RecurringListSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RecurringListSheet(),
    );
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':   return 'Hàng ngày';
      case 'weekly':  return 'Hàng tuần';
      case 'monthly': return 'Hàng tháng';
      default:        return frequency;
    }
  }

  String _formatAmount(int amount) {
    return '${CurrencyFormatter.format(amount)} ₫';
  }

  String _formatNextRun(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Giao dịch định kỳ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Thêm định kỳ mới',
                    onPressed: () => _showAddDialog(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: Consumer<RecurringTransactionViewModel>(
                builder: (context, vm, _) {
                  if (vm.isLoading && vm.recurrings.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (vm.errorMessage != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '⚠️ ${vm.errorMessage}',
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final rules = vm.recurrings;

                  if (rules.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📋', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có giao dịch định kỳ nào',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return _buildRuleRow(context, rule, vm);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRuleRow(
    BuildContext context,
    RecurringTransaction rule,
    RecurringTransactionViewModel vm,
  ) {
    final catVM = context.read<CategoryViewModel>();
    final knownCats = catVM.activeCategories.isNotEmpty
        ? catVM.activeCategories
        : seedCategories;
    final category = knownCats.firstWhere(
      (c) => c.name == rule.categoryName,
      orElse: () => knownCats.first,
    );

    return Dismissible(
      key: Key(rule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xóa định kỳ?'),
            content: Text('Xóa "${category.emoji} ${category.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => vm.deleteRecurring(rule.id),
      child: ListTile(
        leading: Text(category.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(category.name),
        subtitle: Text(
          '${_formatAmount(rule.amount)} • ${_frequencyLabel(rule.frequency)} • Tiếp: ${_formatNextRun(rule.nextRunAt)}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        trailing: Switch(
          value: rule.isActive,
          onChanged: (_) => vm.toggleActive(rule.id),
        ),
        onTap: () => _showEditDialog(context, rule),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final result = await RecurringEditDialog.show(context);
    if (result == null) return;
    if (!context.mounted) return;
    final vm = context.read<RecurringTransactionViewModel>();
    await vm.addRecurring(
      categoryName: result.categoryName,
      categoryId: result.categoryId,
      amount: result.amount,
      note: result.note,
      frequency: result.frequency,
      startDate: result.startDate,
    );
  }

  Future<void> _showEditDialog(BuildContext context, RecurringTransaction rule) async {
    final result = await RecurringEditDialog.show(context, existing: rule);
    if (result == null) return;
    if (!context.mounted) return;
    final vm = context.read<RecurringTransactionViewModel>();
    if (result.id != null) {
      final updated = rule.copyWith(
        categoryName: result.categoryName,
        categoryId: result.categoryId,
        amount: result.amount,
        note: result.note,
        frequency: result.frequency,
        nextRunAt: result.startDate,
      );
      await vm.updateRecurring(updated);
    }
  }
}
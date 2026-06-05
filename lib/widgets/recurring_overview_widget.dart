import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../viewmodels/recurring_viewmodel.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import 'recurring_edit_dialog.dart';

class RecurringOverviewWidget extends StatelessWidget {
  const RecurringOverviewWidget({super.key});

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily': return 'Hàng ngày';
      case 'weekly': return 'Hàng tuần';
      case 'monthly': return 'Hàng tháng';
      default: return frequency;
    }
  }

  String _formatAmount(int amount) {
    return '${CurrencyFormatter.format(amount)} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecurringTransactionViewModel>(
      builder: (context, vm, _) {
        final rules = vm.recurrings;
        final maxDisplay = 5;
        final displayRules = rules.take(maxDisplay).toList();
        final hasMore = rules.length > maxDisplay;

        if (vm.isLoading && rules.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📅 Giao dịch định kỳ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddDialog(context),
                  tooltip: 'Thêm định kỳ mới',
                ),
              ],
            ),
            if (rules.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Chưa có giao dịch định kỳ nào. Nhấn + để thêm.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else ...[
              ...displayRules.map((rule) => _buildRuleCard(context, rule)),
              if (hasMore)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${rules.length - maxDisplay} mục nữa...')),
                    );
                  },
                  child: Text('Xem thêm ${rules.length - maxDisplay} mục'),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRuleCard(BuildContext context, RecurringTransaction rule) {
    final category = Category.predefined.firstWhere(
      (c) => c.name == rule.categoryName,
      orElse: () => Category.predefined.first,
    );

    return Dismissible(
      key: Key(rule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xóa định kỳ?'),
            content: Text('Xóa "${category.emoji} ${category.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
            ],
          ),
        );
      },
      onDismissed: (_) {
        context.read<RecurringTransactionViewModel>().deleteRecurring(rule.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Text(category.emoji, style: const TextStyle(fontSize: 24)),
          title: Text(category.name),
          subtitle: Text(
            '${_formatAmount(rule.amount)} • ${_frequencyLabel(rule.frequency)}',
          ),
          trailing: Switch(
            value: rule.isActive,
            onChanged: (_) {
              context.read<RecurringTransactionViewModel>().toggleActive(rule.id);
            },
          ),
          onTap: () => _showEditDialog(context, rule),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final result = await RecurringEditDialog.show(context);
    if (result != null && context.mounted) {
      final vm = context.read<RecurringTransactionViewModel>();
      await vm.addRecurring(
        categoryName: result.categoryName,
        amount: result.amount,
        note: result.note,
        frequency: result.frequency,
        startDate: result.startDate,
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, RecurringTransaction rule) async {
    final result = await RecurringEditDialog.show(context, existing: rule);
    if (result != null && context.mounted) {
      final vm = context.read<RecurringTransactionViewModel>();
      if (result.id != null) {
        final updated = rule.copyWith(
          categoryName: result.categoryName,
          amount: result.amount,
          note: result.note,
          frequency: result.frequency,
          nextRunAt: result.startDate,
        );
        await vm.updateRecurring(updated);
      }
    }
  }
}
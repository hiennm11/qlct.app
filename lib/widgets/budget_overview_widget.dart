import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/budget_viewmodel.dart';
import '../models/budget_status.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import 'budget_edit_dialog.dart';

/// Widget displaying budget overview with cards
class BudgetOverviewWidget extends StatelessWidget {
  const BudgetOverviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.budgets.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '💼',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ngân sách tháng',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (viewModel.budgetStatuses.isEmpty)
                  _EmptyState()
                else
                  ...viewModel.budgetStatuses.map((status) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetCard(status: status),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Chưa có ngân sách. Nhấn để thêm.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => showBudgetEditDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Thêm ngân sách'),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetStatus status;

  const _BudgetCard({required this.status});

  Color _getProgressColor() {
    switch (status.alertLevel) {
      case AlertLevel.normal:
        return AppColors.success;
      case AlertLevel.warning:
        return AppColors.warning;
      case AlertLevel.exceeded:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = status.limit > 0 ? status.spent / status.limit : 0.0;
    final progressClamped = progress.clamp(0.0, 1.0);

    return InkWell(
      onTap: () => showBudgetEditDialog(
        context,
        categoryName: status.categoryName,
        currentLimit: status.limit,
        currentThreshold: null,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(status.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.categoryName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${CurrencyFormatter.format(status.spent)} / ${CurrencyFormatter.format(status.limit)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressClamped,
              backgroundColor: AppColors.gray300,
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${status.percentUsed}%',
                  style: TextStyle(
                    color: _getProgressColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  status.limit > 0
                      ? (status.remaining > 0
                          ? 'Còn lại: ${CurrencyFormatter.format(status.remaining)}'
                          : 'Vượt: ${CurrencyFormatter.format(status.spent - status.limit)}')
                      : 'Chưa đặt ngân sách',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/budget_viewmodel.dart';
import '../models/budget_status.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import 'budget_edit_dialog.dart';
import 'budget_bulk_edit_dialog.dart';
import 'section_header.dart';

/// Widget displaying budget overview with cards
class BudgetOverviewWidget extends StatefulWidget {
  final void Function(String categoryName)? onCategoryTap;

  const BudgetOverviewWidget({super.key, this.onCategoryTap});

  @override
  State<BudgetOverviewWidget> createState() => _BudgetOverviewWidgetState();
}

class _BudgetOverviewWidgetState extends State<BudgetOverviewWidget> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.budgets.isEmpty && viewModel.totalBudget == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final allStatuses = viewModel.budgetStatuses;
        final alertStatuses = allStatuses
            .where((s) => s.alertLevel == AlertLevel.warning || s.alertLevel == AlertLevel.exceeded)
            .toList();
        final normalStatuses = allStatuses
            .where((s) => s.alertLevel == AlertLevel.normal)
            .toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  emoji: '💼',
                  title: 'Ngân sách tháng',
                  onAction: () => showBudgetBulkEditDialog(context),
                  actionIcon: Icons.edit,
                ),
                const SizedBox(height: 16),
                if (viewModel.totalBudget != null) ...[
                  _TotalBudgetBar(status: viewModel.totalBudgetStatus!),
                  const SizedBox(height: 16),
                ],
                if (allStatuses.isEmpty && viewModel.totalBudget == null)
                  const _EmptyState()
                else ...[
                  ...alertStatuses.map((status) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetCard(
                          status: status,
                          onCategoryTap: widget.onCategoryTap,
                        ),
                      )),
                  if (normalStatuses.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: OutlinedButton.icon(
                        icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
                        label: Text(_showAll
                            ? 'Thu gọn'
                            : 'Xem tất cả ${normalStatuses.length} ngân sách khác'),
                        onPressed: () => setState(() => _showAll = !_showAll),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_showAll)
                    ...normalStatuses.map((status) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BudgetCard(
                            status: status,
                            onCategoryTap: widget.onCategoryTap,
                          ),
                        )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TotalBudgetBar extends StatelessWidget {
  final TotalBudgetStatus status;

  const _TotalBudgetBar({required this.status});

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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💰', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Tổng: ${CurrencyFormatter.format(status.limit)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '${status.percentUsed}%',
                style: TextStyle(
                  color: _getProgressColor(),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã tiêu: ${CurrencyFormatter.format(status.spent)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Còn: ${CurrencyFormatter.format(status.remaining)}',
                style: TextStyle(
                  color: _getProgressColor(),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
          onPressed: () => showBudgetBulkEditDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Thiết lập ngân sách'),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetStatus status;
  final void Function(String categoryName)? onCategoryTap;

  const _BudgetCard({required this.status, this.onCategoryTap});

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
      onTap: () => onCategoryTap?.call(status.categoryName),
      onLongPress: () => showBudgetEditDialog(
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
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Sửa ngân sách',
                  onPressed: () => showBudgetEditDialog(
                    context,
                    categoryName: status.categoryName,
                    currentLimit: status.limit,
                    currentThreshold: null,
                  ),
                ),
                const SizedBox(width: 8),
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
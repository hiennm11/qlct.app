import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/monthly_review_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../models/monthly_review_data.dart';

/// Static Vietnamese month names — no locale-data dependency.
const _viMonthNames = [
  'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
  'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
  'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
];

String _formatViMonth(DateTime date) =>
    '${_viMonthNames[date.month - 1]} ${date.year}';

/// Full-screen Monthly Review screen.
/// Opens from StatsWidget / monthly stats card.
class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({super.key});

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MonthlyReviewViewModel>().loadMonth();
      }
    });
  }

  Future<void> _pickMonth() async {
    final vm = context.read<MonthlyReviewViewModel>();
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final selected = vm.selectedMonth;

    // Allow picking up to current month
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(selected.year - 5, 1, 1),
      lastDate: currentMonth,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      await vm.selectMonth(DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review tháng'),
      ),
      body: Consumer<MonthlyReviewViewModel>(
        builder: (context, vm, _) {
          return Column(
            children: [
              _MonthHeader(
                vm: vm,
                onPickMonth: _pickMonth,
              ),
              Expanded(
                child: _buildBody(vm),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(MonthlyReviewViewModel vm) {
    if (vm.isLoading || vm.data == null) {
      return const _LoadingView();
    }
    if (vm.errorMessage != null) {
      return _ErrorView(message: vm.errorMessage!);
    }
    final data = vm.data!;
    if (data.spendingTotal == 0 && data.investmentTotal == 0) {
      return const _EmptyStateView();
    }
    return _ReviewContent(data: data);
  }
}

class _MonthHeader extends StatelessWidget {
  final MonthlyReviewViewModel vm;
  final VoidCallback onPickMonth;
  const _MonthHeader({required this.vm, required this.onPickMonth});

  @override
  Widget build(BuildContext context) {
    final monthLabel = _formatViMonth(vm.selectedMonth);
    return Material(
      color: AppColors.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 22),
              tooltip: 'Tháng trước',
              onPressed: vm.canGoPrevious ? vm.previousMonth : null,
            ),
            Expanded(
              child: InkWell(
                key: const Key('month-picker'),
                onTap: onPickMonth,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          monthLabel,
                          key: const Key('month-label'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 22),
              tooltip: 'Tháng sau',
              onPressed: vm.canGoNext ? vm.nextMonth : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<MonthlyReviewViewModel>().refresh(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Chưa có giao dịch trong tháng này',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewContent extends StatelessWidget {
  final MonthlyReviewData data;
  const _ReviewContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<MonthlyReviewViewModel>().refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OverviewSection(data: data),
          const SizedBox(height: 16),
          _CategoryChangesSection(data: data),
          const SizedBox(height: 16),
          _FixedExpenseSection(data: data),
          const SizedBox(height: 16),
          _CategoryHighlightsSection(data: data),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String emoji;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.emoji,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final MonthlyReviewData data;
  const _OverviewSection({required this.data});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tổng quan tháng',
      emoji: '📊',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricRow(label: 'Tổng dòng tiền ra', amount: data.totalOutflow, bold: true),
          const SizedBox(height: 8),
          _MetricRow(label: 'Chi tiêu sinh hoạt', amount: data.spendingTotal, color: AppColors.primary),
          const SizedBox(height: 4),
          _MetricRow(label: 'Đầu tư', amount: data.investmentTotal, color: AppColors.secondary),
          const SizedBox(height: 12),
          if (data.spendingDelta != 0)
            _DeltaRow(
              label: 'So với tháng trước',
              delta: data.spendingDelta,
            ),
          if (data.biggestSpendingDay != null) ...[
            const SizedBox(height: 12),
            _BiggestDayRow(day: data.biggestSpendingDay!),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool bold;
  final Color? color;
  const _MetricRow({required this.label, required this.amount, this.bold = false, this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final String label;
  final int delta;
  const _DeltaRow({required this.label, required this.delta});
  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final color = isPositive ? AppColors.error : AppColors.success;
    final prefix = isPositive ? '+' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          '$prefix${CurrencyFormatter.format(delta)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _BiggestDayRow extends StatelessWidget {
  final MonthlyReviewDaySummary day;
  const _BiggestDayRow({required this.day});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Ngày tiêu nhiều nhất', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          '${DateFormatter.formatDate(day.date)} — ${CurrencyFormatter.format(day.totalAmount)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _CategoryChangesSection extends StatelessWidget {
  final MonthlyReviewData data;
  const _CategoryChangesSection({required this.data});
  @override
  Widget build(BuildContext context) {
    final hasData = data.biggestIncrease != null || data.biggestDecrease != null;
    return _SectionCard(
      title: 'Biến động so với tháng trước',
      emoji: '📈',
      child: hasData
          ? Column(
              children: [
                if (data.biggestIncrease != null)
                  _DeltaCategoryTile(
                    title: 'Tăng nhiều nhất',
                    delta: data.biggestIncrease!,
                    onTap: () => _navigateToCategory(context, data.biggestIncrease!.categoryName, data),
                  ),
                if (data.biggestIncrease != null && data.biggestDecrease != null)
                  const SizedBox(height: 8),
                if (data.biggestDecrease != null)
                  _DeltaCategoryTile(
                    title: 'Giảm nhiều nhất',
                    delta: data.biggestDecrease!,
                    onTap: () => _navigateToCategory(context, data.biggestDecrease!.categoryName, data),
                  ),
              ],
            )
          : const Text(
              'Chưa có dữ liệu so sánh',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
    );
  }

  static void _navigateToCategory(BuildContext context, String categoryName, MonthlyReviewData data) {
    final expenseVm = context.read<ExpenseViewModel>();
    final monthStart = data.currentPeriodStart;
    final monthEnd = data.currentPeriodEnd;
    expenseVm.setCategoryFilter(categoryName);
    expenseVm.setDateRangeFilter(monthStart, monthEnd);
    Navigator.of(context).pop();
  }
}

class _DeltaCategoryTile extends StatelessWidget {
  final String title;
  final MonthlyReviewCategoryDelta delta;
  final VoidCallback onTap;
  const _DeltaCategoryTile({required this.title, required this.delta, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isPositive = delta.deltaVnd > 0;
    final color = isPositive ? AppColors.error : AppColors.success;
    final prefix = isPositive ? '+' : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(delta.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(delta.categoryName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (delta.isNewlyIncurred)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Mới phát sinh', style: TextStyle(fontSize: 10, color: AppColors.warning)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${CurrencyFormatter.format(delta.deltaVnd)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                if (!delta.isNewlyIncurred)
                  Text(
                    '${delta.deltaPercent.toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedExpenseSection extends StatelessWidget {
  final MonthlyReviewData data;
  const _FixedExpenseSection({required this.data});
  @override
  Widget build(BuildContext context) {
    final fixed = data.fixedExpenseSummary;
    return _SectionCard(
      title: 'Chi phí cố định',
      emoji: '🔁',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng chi phí cố định', style: TextStyle(fontWeight: FontWeight.w500)),
              Text(CurrencyFormatter.format(fixed.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (fixed.subscriptionAmount > 0)
            _MetricRow(label: 'Subscription', amount: fixed.subscriptionAmount),
          if (fixed.recurringGeneratedAmount > 0)
            _MetricRow(label: 'Tự động định kỳ', amount: fixed.recurringGeneratedAmount),
          if (fixed.activeRecurringRules.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Quy tắc đang chạy', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...fixed.activeRecurringRules.map((rule) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(rule.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(rule.categoryName)),
                      Text(CurrencyFormatter.format(rule.amount), style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _CategoryHighlightsSection extends StatelessWidget {
  final MonthlyReviewData data;
  const _CategoryHighlightsSection({required this.data});
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Category nổi bật',
      emoji: '🏆',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...data.topCategories.map((cat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => _navigateToCategory(context, cat.categoryName),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.categoryName, style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: cat.percentOfSpending / 100,
                                minHeight: 4,
                                backgroundColor: AppColors.gray200,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(CurrencyFormatter.format(cat.amount), style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              )),
          if (data.remainingCategoryTotal > 0) ...[
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Còn lại', style: TextStyle(color: AppColors.textSecondary)),
                Text(CurrencyFormatter.format(data.remainingCategoryTotal),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (data.budgetHighlights.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Ngân sách vượt', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...data.budgetHighlights.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: () => _navigateToCategory(context, b.categoryName),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(b.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(b.categoryName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text('${b.percentUsed}%', style: TextStyle(
                            color: b.isExceeded ? AppColors.error : AppColors.warning,
                            fontWeight: FontWeight.w600,
                          )),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _navigateToCategory(BuildContext context, String categoryName) {
    final expenseVm = context.read<ExpenseViewModel>();
    final monthStart = data.currentPeriodStart;
    final monthEnd = data.currentPeriodEnd;
    expenseVm.setCategoryFilter(categoryName);
    expenseVm.setDateRangeFilter(monthStart, monthEnd);
    Navigator.of(context).pop();
  }
}
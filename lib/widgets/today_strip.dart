import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../viewmodels/budget_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): today strip inline dưới
/// NoteEntry. 3 phần: spent ("Hôm nay -X") + remaining ("Còn lại Y") +
/// LinearProgressIndicator (6px, primary, max-clamp 1.0).
///
/// Source: `ExpenseStats.todayExpense` (spending-only) +
/// `BudgetViewModel.totalBudgetStatus.remaining` (spending-only) +
/// computed `daysLeftInMonth`.
///
/// Edge cases (handled):
/// - daysLeft == 0 → progress = 0, no div-by-zero.
/// - totalBudget null → render "Chưa đặt ngân sách" placeholder, progress 0.
/// - remaining < 0 (overspent) → progress max-clamp 1.0 + "Vượt X" suffix.
/// - todaySpent == 0 → "Chưa chi hôm nay" thay "Hôm nay -0đ".
class TodayStrip extends StatelessWidget {
  const TodayStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseViewModel, BudgetViewModel>(
      builder: (context, expVM, budVM, _) {
        final stats = expVM.stats;
        final todaySpent = stats.todayExpense;
        final totalStatus = budVM.totalBudgetStatus;
        final totalBudget = budVM.totalBudget;
        final monthRem = totalStatus?.remaining ?? 0;
        final now = DateTime.now();
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = lastDay - now.day;

        final dailyAllowance = daysLeft > 0 && monthRem > 0
            ? monthRem / daysLeft
            : 0.0;
        final progress = dailyAllowance > 0
            ? (todaySpent / dailyAllowance).clamp(0.0, 1.0)
            : 0.0;

        return Card(
          key: const Key('today-strip'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSpentLine(context, todaySpent, dailyAllowance),
                const SizedBox(height: 4),
                _buildRemainingLine(context, totalBudget, monthRem, daysLeft),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const Key('today-strip-progress'),
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.gray100,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpentLine(BuildContext context, int todaySpent, double dailyAllowance) {
    if (todaySpent == 0) {
      return const Text(
        'Chưa chi hôm nay',
        key: Key('today-strip-spent'),
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      );
    }
    return Text(
      'Hôm nay -${CurrencyFormatter.format(todaySpent)}',
      key: const Key('today-strip-spent'),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildRemainingLine(
    BuildContext context,
    int? totalBudget,
    int monthRem,
    int daysLeft,
  ) {
    if (totalBudget == null) {
      return const Text(
        'Chưa đặt ngân sách tháng này',
        key: Key('today-strip-remaining'),
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      );
    }
    if (monthRem < 0) {
      return Text(
        'Vượt ${CurrencyFormatter.format(monthRem.abs())}',
        key: const Key('today-strip-remaining'),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.error,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Text(
      'Còn lại ${CurrencyFormatter.format(monthRem)} · $daysLeft ngày',
      key: const Key('today-strip-remaining'),
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}

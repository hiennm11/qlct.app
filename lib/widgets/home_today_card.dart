import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/budget_status.dart';
import '../viewmodels/budget_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';

/// ADR-0081 (Epic 6.3 Home — 4 Tinted Cards): compact "1 dòng hôm nay +
/// progress bar" card. Thay thế StatsWidget 3-stat-card cũ ở vị trí top-of-
/// Home. Read từ ExpenseViewModel.stats.todayExpense + số tx hôm nay,
/// BudgetViewModel.totalBudgetStatus cho progress + còn lại.
///
/// Visual: tinted teal (primary @ 0.08 bg, 1.5px border), icon wallet
/// trong box nhạt ở góc phải, big number hôm nay (32px w700), "5 giao
/// dịch" + "Còn 3.750.000 đ" ở dưới, LinearProgressBar với color map
/// theo status.alertLevel (success/warning/error).
///
/// Empty: nếu todayExpense == 0 VÀ totalBudgetStatus == null → SizedBox.shrink
/// (key: 'home-today-empty'). Nếu todayExpense == 0 nhưng có budget → vẫn
/// render với big number "0 ₫".
class HomeTodayCard extends StatelessWidget {
  const HomeTodayCard({super.key, this.onTap});

  /// Optional tap callback. Khi null, card không có InkWell ripple.
  /// Host có thể wire navigate-to-TxHub-filtered-by-today nếu muốn.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseViewModel, BudgetViewModel>(
      builder: (context, expenseVM, budgetVM, _) {
        final todayExpense = expenseVM.stats.todayExpense;
        final todayCount = _countToday(expenseVM.allTransactions);
        final status = budgetVM.totalBudgetStatus;

        // Empty case: 0 hôm nay + không có budget → ẩn hoàn toàn.
        if (todayExpense == 0 && status == null) {
          return const SizedBox.shrink(key: Key('home-today-empty'));
        }

        return _buildCard(
          context: context,
          todayExpense: todayExpense,
          todayCount: todayCount,
          status: status,
        );
      },
    );
  }

  /// Số transaction trong ngày hôm nay (00:00 → 23:59:59 local).
  int _countToday(List<dynamic> txs) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return txs.where((tx) {
      final d = (tx as dynamic).date as DateTime;
      return !d.isBefore(start) && !d.isAfter(end);
    }).length;
  }

  Widget _buildCard({
    required BuildContext context,
    required int todayExpense,
    required int todayCount,
    required TotalBudgetStatus? status,
  }) {
    final card = Card(
      key: const Key('home-today-card'),
      color: AppColors.primary.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row top: label + big number (left) | icon box (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HÔM NAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(todayExpense),
                          key: const Key('home-today-amount'),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row bottom: tx count (left) | remaining + sub (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    todayCount == 0
                        ? 'Chưa có giao dịch hôm nay'
                        : '$todayCount giao dịch',
                    key: const Key('home-today-tx-count'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (status != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Còn ${CurrencyFormatter.format(status.remaining)}',
                        key: const Key('home-today-remaining'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.format(status.spent)} / '
                        '${CurrencyFormatter.format(status.limit)} tháng này',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  key: const Key('home-today-progress'),
                  value: status.percentUsed / 100,
                  minHeight: 6,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressColor(status.alertLevel),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  /// Map AlertLevel → progress bar fill color. Semantic colors:
  /// normal=primary teal, warning=warning orange, exceeded=error red.
  Color _progressColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.warning:
        return AppColors.warning;
      case AlertLevel.exceeded:
        return AppColors.error;
      case AlertLevel.normal:
        return AppColors.primary;
    }
  }
}

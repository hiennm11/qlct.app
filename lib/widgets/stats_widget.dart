import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Widget displaying expense statistics cards
class StatsWidget extends StatelessWidget {
  const StatsWidget({
    super.key,
    this.onTapToday,
    this.onTapWeek,
    this.onTapMonth,
  });

  final VoidCallback? onTapToday;
  final VoidCallback? onTapWeek;
  final VoidCallback? onTapMonth;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseViewModel>(
      builder: (context, viewModel, child) {
        final stats = viewModel.stats;
        final isLoading = viewModel.isLoading;
        final isEmpty = stats.todayExpense == 0 &&
            stats.weekExpense == 0 &&
            stats.monthExpense == 0;

        if (isLoading) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        'Thống kê chi tiêu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _LoadingStatCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _LoadingStatCard()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _LoadingStatCard(),
                  ),
                ],
              ),
            ),
          );
        }

        if (isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        'Thống kê chi tiêu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có chi tiêu tháng này',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
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
                    const Text('💰', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Thống kê chi tiêu',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Hôm nay',
                        amount: stats.todayExpense,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        onTap: onTapToday,
                        showTapIndicator: onTapToday != null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Tuần này',
                        amount: stats.weekExpense,
                        gradient: const LinearGradient(
                          colors: [AppColors.secondary, AppColors.success],
                        ),
                        onTap: onTapWeek,
                        showTapIndicator: onTapWeek != null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _StatCard(
                    label: 'Tháng này',
                    amount: stats.monthExpense,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryHover],
                    ),
                    isWide: true,
                    onTap: onTapMonth,
                    showTapIndicator: onTapMonth != null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int amount;
  final Gradient gradient;
  final bool isWide;
  final VoidCallback? onTap;
  final bool showTapIndicator;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.gradient,
    this.isWide = false,
    this.onTap,
    this.showTapIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (showTapIndicator)
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 14,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: card,
      );
    }

    return card;
  }
}

class _LoadingStatCard extends StatelessWidget {
  const _LoadingStatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 20,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

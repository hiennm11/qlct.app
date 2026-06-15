import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/weekly_review_data.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/weekly_review_viewmodel.dart';
import 'section_header.dart';

/// Weekly Review card on Home. Renders 3 insight chips based on data
/// state (empty / low / normal). Tap-through: set date-range filter
/// (+ optional category) and scroll to TransactionListWidget.
///
/// ADR-0053: Weekly Review Card on Home (Epic 4)
class WeeklyReviewCard extends StatefulWidget {
  const WeeklyReviewCard({
    super.key,
    required this.onCtaTap,
    required this.onTopCategoryTap,
  });

  /// Tap "Xem chi tiết tuần này" — set this-week filter + scroll to list.
  final VoidCallback onCtaTap;

  /// Tap top-category chip — set this-week + category filter + scroll to list.
  final VoidCallback onTopCategoryTap;

  @override
  State<WeeklyReviewCard> createState() => _WeeklyReviewCardState();
}

class _WeeklyReviewCardState extends State<WeeklyReviewCard> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load (idempotent — VM skips if already loaded & not dirty).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WeeklyReviewViewModel>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeeklyReviewViewModel>(
      builder: (context, vm, _) {
        if (vm.errorMessage != null) {
          return _ErrorView(
            message: vm.errorMessage!,
            onRetry: () => vm.refresh(),
          );
        }

        if (vm.isLoading && vm.data == null) {
          return const _LoadingView();
        }

        final data = vm.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        if (data.lowDataState == WeeklyReviewLowDataState.empty) {
          return const _WeeklyReviewEmptyState();
        }

        if (data.lowDataState == WeeklyReviewLowDataState.low) {
          return _LowDataView(
            data: data,
            onCtaTap: widget.onCtaTap,
          );
        }

        return Consumer<CategoryViewModel>(
          builder: (context, catVM, _) {
            return _NormalView(
              data: data,
              categories: catVM.activeCategories,
              onCtaTap: widget.onCtaTap,
              onTopCategoryTap: widget.onTopCategoryTap,
            );
          },
        );
      },
    );
  }
}

// =====================================================================
// Loading / error
// =====================================================================

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(emoji: '📊', title: 'Tuần này'),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Empty state
// =====================================================================

class _WeeklyReviewEmptyState extends StatelessWidget {
  const _WeeklyReviewEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(emoji: '📊', title: 'Tuần này'),
            const SizedBox(height: 16),
            Center(
              child: Column(
                key: const Key('state-weekly-review-empty'),
                children: const [
                  Icon(Icons.event_busy, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có giao dịch tuần này',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Bắt đầu thêm giao dịch để xem tổng kết tuần.',
                    key: Key('state-weekly-review-empty-hint'),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Low-data view (1 insight chip)
// =====================================================================

class _LowDataView extends StatelessWidget {
  const _LowDataView({required this.data, required this.onCtaTap});
  final WeeklyReviewData data;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('state-weekly-review-card'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(data),
            const SizedBox(height: 12),
            Container(
              key: const Key('state-weekly-review-insight-primary'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Đã chi ${CurrencyFormatter.format(data.weekSpent)} '
                'trong ${data.daysLogged} ngày qua',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('state-weekly-review-cta'),
                onPressed: onCtaTap,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Xem chi tiết tuần này'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Normal view (3 insight chips)
// =====================================================================

class _NormalView extends StatelessWidget {
  const _NormalView({
    required this.data,
    required this.categories,
    required this.onCtaTap,
    required this.onTopCategoryTap,
  });
  final WeeklyReviewData data;
  final List<Category> categories;
  final VoidCallback onCtaTap;
  final VoidCallback onTopCategoryTap;

  @override
  Widget build(BuildContext context) {
    final categoriesById = {for (final c in categories) c.id: c};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('state-weekly-review-card'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(data),
            const SizedBox(height: 12),
            _compareChip(data),
            const SizedBox(height: 8),
            _topCategoryChip(data, categoriesById),
            const SizedBox(height: 8),
            _upcomingChip(data, categoriesById),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('state-weekly-review-cta'),
                onPressed: onCtaTap,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Xem chi tiết tuần này'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareChip(WeeklyReviewData d) {
    final deltaDir = d.spendingDelta;
    final isUp = deltaDir > 0;
    final isDown = deltaDir < 0;
    final color = isUp
        ? Colors.red
        : (isDown ? AppColors.success : AppColors.textSecondary);
    final arrow = isUp ? '▲' : (isDown ? '▼' : '→');
    final deltaAbs = CurrencyFormatter.format(deltaDir.abs());

    String body;
    if (!d.hasEnoughDataForDelta) {
      body = 'Tuần này chi ${CurrencyFormatter.format(d.weekSpent)}. '
          'Chưa có dữ liệu tuần trước để so sánh.';
    } else {
      body = 'Tuần này chi ${CurrencyFormatter.format(d.weekSpent)}, '
          '$arrow $deltaAbs so với tuần trước '
          '(${CurrencyFormatter.format(d.prevWeekSpent)})';
    }

    return Container(
      key: const Key('state-weekly-review-insight-primary'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SO SÁNH TUẦN TRƯỚC',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _topCategoryChip(
    WeeklyReviewData d,
    Map<String, Category> categoriesById,
  ) {
    final catId = d.topCategoryId;
    final cat = catId != null ? categoriesById[catId] : null;
    final emoji = cat?.emoji ?? '📌';
    final name = cat?.name ?? 'Danh mục';
    final deltaAbs = CurrencyFormatter.format(d.topCategoryDelta.abs());
    final isUp = d.topCategoryDelta > 0;
    final arrow = isUp ? '+' : '−';
    final sign = isUp ? '+' : '−';

    return InkWell(
      key: const Key('state-weekly-review-insight-secondary'),
      onTap: catId != null ? onTopCategoryTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DANH MỤC TĂNG MẠNH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$name: $sign$deltaAbs',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (d.daysLogged > 0)
                  Text(
                    '${d.daysLogged}/7 ngày',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                if (catId != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingChip(
    WeeklyReviewData d,
    Map<String, Category> categoriesById,
  ) {
    final hasRecurring = d.upcomingRecurringCount > 0;
    final hasRisk = d.budgetRiskCategoryIds.isNotEmpty;
    if (!hasRecurring && !hasRisk) {
      return const SizedBox.shrink();
    }

    final parts = <String>[];
    if (hasRecurring) {
      final n = d.upcomingRecurringCount;
      parts.add('Có $n khoản định kỳ sẽ chạy trong 7 ngày tới');
    }
    if (hasRisk) {
      final n = d.budgetRiskCategoryIds.length;
      parts.add('$n ngân sách gần chạm ngưỡng');
    }

    return Container(
      key: const Key('state-weekly-review-insight-tertiary'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SẮP TỚI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(parts.join(' · '), style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// =====================================================================
// Helpers
// =====================================================================

/// Header row: emoji + title (Expanded) + week-range label. Built manually
/// (no SectionHeader) to avoid Row-inside-Row + Spacer unbounded-width
/// conflict (SectionHeader has its own Row with Expanded for title).
Widget _buildHeader(WeeklyReviewData data) {
  return Row(
    children: [
      const Text('📊', style: TextStyle(fontSize: 24)),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Tuần này',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      Text(
        _weekRangeLabel(data.currentWeekStart, data.currentWeekEnd),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

String _weekRangeLabel(DateTime start, DateTime end) {
  String two(int n) => n.toString().padLeft(2, '0');
  // end có thể là "now" (giữa tuần) — chỉ show ngày end nếu khác start
  final endLabel = end.day != start.day
      ? ' → ${two(end.day)}/${end.month}'
      : '';
  return '${two(start.day)}/${start.month}$endLabel';
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/weekly_review_viewmodel.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/chart_widget.dart';
import '../widgets/month_close_banner.dart';
import '../widgets/weekly_review_card.dart';
import 'monthly_plan_screen.dart';
import 'monthly_review_screen.dart';
import 'transaction_hub_screen.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): BudgetHubScreen — push từ
/// bottom nav index 2. Sections (top→bottom):
/// 1. MonthCloseBanner (ADR-0056) — orchestrate cuối tháng (day>=25)
/// 2. WeeklyReviewCard (ADR-0053) — tuần này insights
/// 3. BudgetOverviewWidget (current month) — per-category budget
/// 4. Shortcut card — Monthly plan + Monthly review entries
/// 5. ChartWidget (conditional: monthExpense > 0) — biểu đồ danh mục
///
/// ADR-0081 (Epic 6.3 Home — 4 Tinted Cards): Home → 4-card note-first
/// stripped BudgetOverview + MonthClose + WeeklyReview + inline
/// TransactionListWidget. Relocate toàn bộ sang Budget Tab để giữ Home
/// gọn. onCtaTap / onTopCategoryTap / onCategoryTap navigate tới
/// TransactionHubScreen sau khi set filter.
class BudgetHubScreen extends StatelessWidget {
  const BudgetHubScreen({super.key});

  /// Tap weekly review CTA → set this-week filter + open TransactionHub.
  void _openThisWeek(BuildContext context) {
    final vm = context.read<ExpenseViewModel>();
    vm.clearFilters();
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    vm.setDateRangeFilter(startOfDay, endOfDay);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionHubScreen()),
    );
  }

  /// Tap top-category chip → set this-week + category filter + open hub.
  void _openThisWeekCategory(BuildContext context) {
    final weeklyVM = context.read<WeeklyReviewViewModel>();
    final categoryId = weeklyVM.data?.topCategoryId;
    if (categoryId == null) return;
    final vm = context.read<ExpenseViewModel>();
    vm.clearFilters();
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    vm.setDateRangeFilter(startOfDay, endOfDay);
    // Map categoryId → categoryName (WeeklyReviewData chỉ lưu id).
    final categories = context.read<CategoryViewModel>().activeCategories;
    final cat = categories.where((c) => c.id == categoryId).firstOrNull;
    if (cat != null) {
      vm.setCategoryFilter(cat.name);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionHubScreen()),
    );
  }

  /// Tap category row trong BudgetOverview → set category filter + open hub.
  void _openCategory(BuildContext context, String categoryName) {
    final vm = context.read<ExpenseViewModel>();
    vm.clearFilters();
    vm.setCategoryFilter(categoryName);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionHubScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('hub-budget'),
      appBar: AppBar(title: const Text('Ngân sách')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ADR-0081: MonthClose (ADR-0056) + WeeklyReview (ADR-0053) move từ
          // Home xuống đây. Tap CTA → set filter + open TransactionHub.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: MonthCloseBanner(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WeeklyReviewCard(
              onCtaTap: () => _openThisWeek(context),
              onTopCategoryTap: () => _openThisWeekCategory(context),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BudgetOverviewWidget(
              onCategoryTap: (categoryName) => _openCategory(context, categoryName),
            ),
          ),
          const SizedBox(height: 16),
          // Monthly plan + review shortcuts.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('hub-budget-plan'),
                    leading: const Icon(Icons.event_note),
                    title: const Text('Kế hoạch tháng tới'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MonthlyPlanScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('hub-budget-review'),
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('Tổng kết tháng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MonthlyReviewScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Chart inline (moved from Home ADR-0067).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<CategoryViewModel>(
              builder: (context, categoryVM, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text('📊', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Text(
                              'Biểu đồ danh mục',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ADR-0074: bump host constraint 220 → 460.
                      // ChartWidget internal layout redesigned to vertical
                      // stack (pie 180×180 on top + 2-col Wrap legend) — fits
                      // 5-8 categories in 3-4 rows of legend. 12+ cats
                      // (stress edge) overflow documented.
                      //
                      // ADR-0079: bump 420 → 460 vì legend row fontSize 10→12
                      // tăng row height ~10px × 4 rows = 40px headroom cần.
                      SizedBox(
                        height: 460,
                        child: ChartWidget(
                          activeCategories: categoryVM.activeCategories,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

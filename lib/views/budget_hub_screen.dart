import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/category_viewmodel.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/chart_widget.dart';
import 'monthly_plan_screen.dart';
import 'monthly_review_screen.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): BudgetHubScreen — push từ
/// bottom nav index 2. Sections: BudgetOverviewWidget (current month) +
/// MonthlyPlan shortcut + ChartWidget (conditional: monthExpense > 0) +
/// MonthlyReviewScreen entry.
class BudgetHubScreen extends StatelessWidget {
  const BudgetHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('hub-budget'),
      appBar: AppBar(title: const Text('Ngân sách')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BudgetOverviewWidget(
              onCategoryTap: (_) {},
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
                      // ADR-0074: bump host constraint 220 → 420.
                      // ChartWidget internal layout redesigned to vertical
                      // stack (pie 180×180 on top + 2-col Wrap legend) — fits
                      // 5-8 categories in 3-4 rows of legend. 12+ cats
                      // (stress edge) overflow documented.
                      SizedBox(
                        height: 420,
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

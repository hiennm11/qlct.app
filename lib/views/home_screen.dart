import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';

import '../viewmodels/recurring_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/weekly_review_viewmodel.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/month_close_banner.dart';
import '../widgets/note_entry.dart';
import '../widgets/recent_transactions_card.dart';
import '../widgets/today_strip.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/weekly_review_card.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'account_hub_screen.dart';
import 'backup_restore_screen.dart';
import 'budget_hub_screen.dart';
import 'transaction_hub_screen.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): HomeScreen restructured.
/// Sections (top→bottom): NoteEntry → TodayStrip → BudgetOverviewWidget →
/// MonthCloseBanner (ADR-0056) → WeeklyReviewCard (ADR-0053) →
/// RecentTransactionsCard (3 rows + "Xem tất cả") → TransactionListWidget.
/// Bottom navigation 4-tab (Tổng quan active / Giao dịch / Ngân sách / Tài khoản).
/// Per grill Q3 option C: hub screens mới (Transaction/Budget/Account).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _transactionListKey = GlobalKey();
  String? _lastShownError;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseViewModel>().addListener(_onExpenseError);

    // ADR-0055 §Phase C: defer RecurringVM.checkAndGenerate ra frame 2.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<RecurringTransactionViewModel>().checkAndGenerate().then((generated) {
          if (mounted && generated > 0) {
            context.read<ExpenseViewModel>().refresh();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    context.read<ExpenseViewModel>().removeListener(_onExpenseError);
    _scrollController.dispose();
    super.dispose();
  }

  void _onExpenseError() {
    final vm = context.read<ExpenseViewModel>();
    final error = vm.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      vm.clearError();
    }
  }

  void _scrollToTransactionList() {
    final ctx = _transactionListKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // Tap-to-scroll-top behavior.
      _scrollToTop();
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    switch (index) {
      case 0:
        setState(() => _currentIndex = 0);
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionHubScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetHubScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountHubScreen()),
        );
        break;
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Quản Lý Chi Tiêu',
      applicationVersion: AppConstants.appVersion,
      applicationIcon: const Icon(Icons.account_balance_wallet, size: 48),
      children: const [
        Text('Ứng dụng quản lý chi tiêu cá nhân với tính năng theo dõi chi tiêu, ngân sách và giao dịch định kỳ.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Quản Lý Chi Tiêu'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              final messenger = ScaffoldMessenger.of(context);
              final viewModel = context.read<ExpenseViewModel>();
              switch (value) {
                case 'export_csv':
                  viewModel.exportAndShareCsv().then((_) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã xuất file CSV')),
                      );
                    }
                  });
                  break;
                case 'export_json':
                  viewModel.exportAndShareJson().then((_) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã xuất file JSON')),
                      );
                    }
                  });
                  break;
                case 'backup':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BackupRestoreScreen(),
                    ),
                  );
                  break;
                case 'about':
                  _showAboutDialog();
                  break;
              }
            },
            itemBuilder: (context) {
              final viewModel = context.read<ExpenseViewModel>();
              final hasFilters = viewModel.hasActiveFilters;
              final count = viewModel.transactions.length;
              final csvLabel = hasFilters
                  ? 'Xuất CSV kết quả lọc ($count mục)'
                  : 'Xuất CSV tất cả ($count mục)';
              final jsonLabel = hasFilters
                  ? 'Xuất JSON kết quả lọc ($count mục)'
                  : 'Xuất JSON tất cả ($count mục)';
              return [
                PopupMenuItem(
                  value: 'export_csv',
                  child: ListTile(
                    leading: const Icon(Icons.table_chart),
                    title: Text(csvLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'export_json',
                  child: ListTile(
                    leading: const Icon(Icons.data_object),
                    title: Text(jsonLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'backup',
                  child: ListTile(
                    leading: Icon(Icons.backup),
                    title: Text('Sao lưu & Khôi phục'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Giới thiệu'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      // ADR-0067 §5: BottomNavigationBar 4-tab.
      bottomNavigationBar: NavigationBar(
        key: const Key('home-bottom-nav'),
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Giao dịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Ngân sách',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ExpenseViewModel>().refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.only(top: 16),
              sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // NoteEntry (ADR-0067 §2) — replaces QuickAddBar.
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: NoteEntry(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // TodayStrip (ADR-0067 §3) — at-a-glance spending vs remaining.
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TodayStrip(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // BudgetOverviewWidget (kept per grill Q1+2 keep MonthCloseBanner/WeeklyReview).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BudgetOverviewWidget(
                  onCategoryTap: (categoryName) {
                    context.read<ExpenseViewModel>().setCategoryFilter(categoryName);
                    _scrollToTransactionList();
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // MonthCloseBanner (ADR-0056) — kept.
            const SliverToBoxAdapter(
              child: MonthCloseBanner(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // WeeklyReviewCard (ADR-0053) — kept.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: WeeklyReviewCard(
                  onCtaTap: () {
                    final vm = context.read<ExpenseViewModel>();
                    vm.clearFilters();
                    final now = DateTime.now();
                    final startOfWeek =
                        now.subtract(Duration(days: now.weekday - 1));
                    vm.setDateRangeFilter(
                      DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
                      DateTime(now.year, now.month, now.day),
                    );
                    _scrollToTransactionList();
                  },
                  onTopCategoryTap: () {
                    final weeklyVM = context.read<WeeklyReviewViewModel>();
                    final categoryId = weeklyVM.data?.topCategoryId;
                    if (categoryId == null) return;
                    final catVM = context.read<CategoryViewModel>();
                    final cat = catVM.activeCategories
                        .where((c) => c.id == categoryId)
                        .firstOrNull;
                    final vm = context.read<ExpenseViewModel>();
                    vm.clearFilters();
                    final now = DateTime.now();
                    final startOfWeek =
                        now.subtract(Duration(days: now.weekday - 1));
                    vm.setDateRangeFilter(
                      DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
                      DateTime(now.year, now.month, now.day),
                    );
                    if (cat != null) {
                      vm.setCategoryFilter(cat.name);
                    }
                    _scrollToTransactionList();
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // RecentTransactionsCard (ADR-0067 §4) — 3 rows + "Xem tất cả".
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RecentTransactionsCard(
                  onSeeAllTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionHubScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Full TransactionListWidget (kept inline on Home for tap-through).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  key: _transactionListKey,
                  child: const TransactionListWidget(),
                ),
              ),
            ),

            const SliverPadding(
              padding: EdgeInsets.only(bottom: 24),
              sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

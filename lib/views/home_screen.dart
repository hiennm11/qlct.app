import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';

import '../viewmodels/recurring_viewmodel.dart';
import '../viewmodels/weekly_review_viewmodel.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/collapsible_recurring_card.dart';
import '../widgets/collapsible_stats_card.dart';
import '../widgets/month_close_banner.dart';
import '../widgets/recent_transactions_card.dart';
import '../widgets/super_input_card.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/weekly_review_card.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'account_hub_screen.dart';
import 'backup_restore_screen.dart';
import 'budget_hub_screen.dart';
import 'transaction_hub_screen.dart';
import '../widgets/quick_templates_strip.dart';

/// ADR-0069 (Epic 6.1 Home — Super-Input): Home restructured thành
/// 1 super-input card (5 methods) + sticky Lưu chung. Bỏ RecentTransactionsCard
/// (redundant với TransactionHubScreen) và inline TodayStrip. Budget summary
/// di chuyển xuống section 5 của SuperInputCard (compact 1 dòng).
///
/// Sections (top→bottom): SuperInputCard → BudgetOverviewWidget →
/// MonthCloseBanner (ADR-0056) → WeeklyReviewCard (ADR-0053) →
/// RecentTransactionsCard (3 tx + "Xem tất cả") →
/// CollapsibleStatsCard (Hôm nay / Tuần này / Tháng này) →
/// CollapsibleRecurringCard (≤5 rules) → TransactionListWidget.
///
/// Bottom navigation 4-tab (Tổng quan active / Giao dịch / Ngân sách / Tài khoản).
///
/// ADR-0080 (Epic 6.2 Home restore): restore Stats + Recurring + Recent
/// từ reference image user gửi 2026-06-16. Stats/Recurring render dạng
/// collapsible (chevron toggle) để tiết kiệm viewport budget. Stats
/// onTap wires today/week/month filter + scroll-to-tx-list, mirror
/// WeeklyReviewCard.onCtaTap pattern.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _transactionListKey = GlobalKey();
  final GlobalKey<SuperInputCardState> _superInputKey =
      GlobalKey<SuperInputCardState>();
  // ADR-0073 (Bug B v3): host-owned proxy ValueNotifier. Pre-v3, host
  // subscribed `_superInputKey.currentState?.changeTick ?? ValueNotifier(0)`
  // ở lúc Scaffold build → child State chưa mount → notifier rác mãi 0
  // → ValueListenableBuilder không rebuild → button stays disabled.
  // Post-v3: proxy rebind sau khi child mount qua addPostFrameCallback.
  final ValueNotifier<int> _saveTick = ValueNotifier<int>(0);
  VoidCallback? _saveTickForward;
  String? _lastShownError;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseViewModel>().addListener(_onExpenseError);

    // ADR-0055 §Phase C: defer RecurringVM.checkAndGenerate ra frame 2.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ADR-0073: rebind host proxy → child changeTick sau khi child mount.
      _attachSuperInputBridge();
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

  // ADR-0073: forward child changeTick bumps → host _saveTick. Phải re-attach
  // mỗi lần child rebuild widget tree mới (GlobalKey vẫn dùng được, nhưng
  // nếu parent rebuild mà key stable thì state giữ nguyên → attach 1 lần đủ).
  // Đề phòng child rebuild (vd: setState trong builder), check trước khi add.
  void _attachSuperInputBridge() {
    final child = _superInputKey.currentState;
    if (child == null) return;
    final tick = child.changeTick;
    if (_saveTickForward != null) {
      tick.removeListener(_saveTickForward!);
    }
    _saveTickForward = () {
      if (mounted) _saveTick.value = tick.value;
    };
    tick.addListener(_saveTickForward!);
    // Force 1 bump để lần build đầu của ValueListenableBuilder ở host
    // thấy state mới nhất (không phải 0 rác).
    _saveTick.value = tick.value;
  }

  @override
  void dispose() {
    context.read<ExpenseViewModel>().removeListener(_onExpenseError);
    final child = _superInputKey.currentState;
    if (child != null && _saveTickForward != null) {
      child.changeTick.removeListener(_saveTickForward!);
    }
    _saveTick.dispose();
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

  void _showAllTemplates() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ManageTemplatesSheet(),
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
      // ADR-0069 §2: sticky bottom — 1 nút Lưu chung (pill teal, 48px).
      // ADR-0073 (Bug B v3): nghe host _saveTick proxy (rebound từ
      // SuperInputCardState.changeTick qua _attachSuperInputBridge) thay vì
      // listen trực tiếp `_superInputKey.currentState?.changeTick ?? …`.
      // Listen trực tiếp race với child mount → notifier rác mãi 0.
      bottomSheet: ValueListenableBuilder<int>(
        valueListenable: _saveTick,
        builder: (context, _, __) {
          final canSave = _superInputKey.currentState?.canSave ?? false;
          return SuperInputSaveButton(
            canSave: canSave,
            onSave: () {
              _superInputKey.currentState?.save();
            },
          );
        },
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

            // ADR-0069 — SuperInputCard (5 input methods + 1 Lưu sticky).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SuperInputCard(
                  key: _superInputKey,
                  onSeeAllTemplates: _showAllTemplates,
                  onNoteFocused: _scrollToTop,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

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
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

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

            // ADR-0080: RecentTransactionsCard (3 tx + "Xem tất cả").
            // Reference image 2026-06-16 yêu cầu restore section này.
            // onSeeAllTap navigate sang TransactionHubScreen.
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RecentTransactionsCard(
                  onSeeAllTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionHubScreen(),
                    ),
                  ),
                ),
              ),
            ),

            // ADR-0080: CollapsibleStatsCard. StatsWidget bị drop khỏi
            // Home trong Epic 6 (ADR-0067/0069), không relocate. Restore
            // dạng collapsible (chevron toggle) — mặc định chỉ thấy
            // header row, expand mới hiện 3 stat cards. onTap wires
            // setDateRangeFilter(today/week/month) + _scrollToTransactionList,
            // mirror WeeklyReviewCard.onCtaTap pattern ở L385-396.
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CollapsibleStatsCard(
                  onTapToday: () {
                    final vm = context.read<ExpenseViewModel>();
                    vm.clearFilters();
                    final now = DateTime.now();
                    vm.setDateRangeFilter(
                      DateTime(now.year, now.month, now.day),
                      DateTime(now.year, now.month, now.day, 23, 59, 59),
                    );
                    _scrollToTransactionList();
                  },
                  onTapWeek: () {
                    final vm = context.read<ExpenseViewModel>();
                    vm.clearFilters();
                    final now = DateTime.now();
                    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                    vm.setDateRangeFilter(
                      DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
                      DateTime(now.year, now.month, now.day, 23, 59, 59),
                    );
                    _scrollToTransactionList();
                  },
                  onTapMonth: () {
                    final vm = context.read<ExpenseViewModel>();
                    vm.clearFilters();
                    final now = DateTime.now();
                    final firstOfMonth = DateTime(now.year, now.month, 1);
                    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);
                    final lastOfMonth = firstOfNextMonth.subtract(const Duration(seconds: 1));
                    vm.setDateRangeFilter(firstOfMonth, lastOfMonth);
                    _scrollToTransactionList();
                  },
                ),
              ),
            ),

            // ADR-0080: CollapsibleRecurringCard. RecurringOverviewWidget
            // bị drop khỏi Home trong Epic 6, không relocate. Restore dạng
            // collapsible. Widget owns add/edit/dismiss/sheet flows
            // internally — không cần callback ở host.
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const CollapsibleRecurringCard(),
              ),
            ),

            // Extra bottom padding to ensure last item not hidden by sticky Save.
            const SliverPadding(
              padding: EdgeInsets.only(bottom: 96),
              sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

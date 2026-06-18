import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';

import '../viewmodels/recurring_viewmodel.dart';
import '../widgets/collapsible_recurring_card.dart';
import '../widgets/collapsible_stats_card.dart';
import '../widgets/home_today_card.dart';
import '../widgets/recent_transactions_card.dart';
import '../widgets/super_input_card.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'account_hub_screen.dart';
import 'backup_restore_screen.dart';
import 'budget_hub_screen.dart';
import 'transaction_hub_screen.dart';
import '../widgets/quick_templates_strip.dart';

/// ADR-0081 (Epic 6.3 Home — 4 Tinted Cards): Home restructured thành
/// 4 card đồng bộ style "tinted Material You" — mỗi card 1 accent color
/// riêng, layout đơn giản hơn reference image user gửi 2026-06-17:
/// 1. **Hôm nay** (teal primary @ 0.08) — `HomeTodayCard` mới, compact
///    1 dòng + progress bar monthly
/// 2. **Gần đây** (orange warning @ 0.08) — `RecentTransactionsCard` có
///    sẵn, restyle
/// 3. **Thống kê** (blue info @ 0.08) — `CollapsibleStatsCard` wrap
///    `StatsWidget` 3 stat
/// 4. **Giao dịch định kỳ** (green success @ 0.08) — `CollapsibleRecurringCard`
///
/// Bottom navigation 4-tab (Tổng quan active / Giao dịch / Ngân sách / Tài khoản).
///
/// Trước (ADR-0069/0080): Home có 8 slivers bao gồm BudgetOverviewWidget +
/// MonthCloseBanner + WeeklyReviewCard + inline TransactionListWidget +
/// 3 collapsible card. User feedback 2026-06-17: "tao k thấy các widget
/// đẹp giống hình, mày chỉ đơn giản là nhét các widget có sẵn" → strip
/// 4 widget nặng sang Budget Tab (xem BudgetHubScreen), giữ Home focused
/// vào input + glance.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
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

  void _openTransactionHub() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionHubScreen()),
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
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ADR-0081: Hôm nay — compact 1 dòng + progress bar monthly
            // (teal tinted). Mới, thay thế 3-stat layout cũ của StatsWidget
            // ở vị trí top-of-Home. onTap: null cho initial commit — không
            // còn target scroll-to-tx-list (TransactionListWidget bỏ khỏi
            // Home, user đi qua "Xem tất cả" → TransactionHub).
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: HomeTodayCard(),
              ),
            ),

            // Gần đây — RecentTransactionsCard (orange tinted), luôn hiển thị.
            // Tap "Xem tất cả" → TransactionHub.
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RecentTransactionsCard(onSeeAllTap: _openTransactionHub),
              ),
            ),

            // Thống kê — CollapsibleStatsCard (blue tinted), mặc định
            // collapsed. onTap today/week/month: null (không còn target
            // scroll-to-tx-list; user mở TransactionHub qua tab "Giao dịch"
            // hoặc "Xem tất cả" của Recent).
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const CollapsibleStatsCard(),
              ),
            ),

            // Giao dịch định kỳ — CollapsibleRecurringCard (green tinted).
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

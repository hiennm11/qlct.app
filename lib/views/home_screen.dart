import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/recurring_viewmodel.dart';
import '../widgets/stats_widget.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/chart_widget.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/recurring_overview_widget.dart';
import '../widgets/quick_add_bar.dart';
import '../core/theme.dart';
import 'backup_restore_screen.dart';

/// Main home screen for the expense tracking app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _transactionListKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _recurringKey = GlobalKey();
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    // Trigger recurring check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RecurringTransactionViewModel>().checkAndGenerate().then((_) {
          if (mounted) {
            context.read<ExpenseViewModel>().refresh();
          }
        });
      }
    });

    // Listen for errors from ExpenseViewModel
    final vm = context.read<ExpenseViewModel>();
    vm.addListener(_onExpenseError);
  }

  @override
  void dispose() {
    final vm = context.read<ExpenseViewModel>();
    vm.removeListener(_onExpenseError);
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
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      vm.clearError();
    }
  }

  void _scrollToSection(GlobalKey key, {double alignment = 0.1}) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: alignment,
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Quản Lý Chi Tiêu',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.account_balance_wallet, size: 48),
      children: const [
        Text('Ứng dụng quản lý chi tiêu cá nhân với tính năng theo dõi chi tiêu, ngân sách và giao dịch định kỳ.'),
      ],
    );
  }

  Widget _buildJumpBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _JumpButton(
            icon: Icons.bar_chart,
            label: 'Tổng quan',
            onTap: () => _scrollToSection(_statsKey),
          ),
          _JumpButton(
            icon: Icons.history,
            label: 'Lịch sử',
            onTap: () => _scrollToSection(_transactionListKey),
          ),
          _JumpButton(
            icon: Icons.repeat,
            label: 'Định kỳ',
            onTap: () => _scrollToSection(_recurringKey),
          ),
        ],
      ),
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await context.read<ExpenseViewModel>().refresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                children: [
                  // Quick add bar
                  const QuickAddBar(),
                  const SizedBox(height: 20),

                  // Budget overview
                  BudgetOverviewWidget(
                    onCategoryTap: (categoryName) {
                      context.read<ExpenseViewModel>().setCategoryFilter(categoryName);
                      _scrollToSection(_transactionListKey);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Transactions list
                  Container(
                    key: _transactionListKey,
                    child: const TransactionListWidget(),
                  ),
                  const SizedBox(height: 20),

                  // Stats section
                  Container(
                    key: _statsKey,
                    child: StatsWidget(
                      onTapToday: () {
                        final vm = context.read<ExpenseViewModel>();
                        vm.clearFilters();
                        vm.setDateFilter(DateTime.now());
                        _scrollToSection(_transactionListKey);
                      },
                      onTapWeek: () {
                        final vm = context.read<ExpenseViewModel>();
                        vm.clearFilters();
                        final now = DateTime.now();
                        final startOfWeek =
                            now.subtract(Duration(days: now.weekday - 1));
                        vm.setDateRangeFilter(
                          DateTime(
                              startOfWeek.year, startOfWeek.month, startOfWeek.day),
                          DateTime(now.year, now.month, now.day),
                        );
                        _scrollToSection(_transactionListKey);
                      },
                      onTapMonth: () {
                        final vm = context.read<ExpenseViewModel>();
                        vm.clearFilters();
                        final now = DateTime.now();
                        final startOfMonth = DateTime(now.year, now.month, 1);
                        vm.setDateRangeFilter(
                          startOfMonth,
                          DateTime(now.year, now.month + 1, 0),
                        );
                        _scrollToSection(_transactionListKey);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Chart
                  const ChartWidget(),
                  const SizedBox(height: 20),

                  // Recurring transactions
                  Container(
                    key: _recurringKey,
                    child: const RecurringOverviewWidget(),
                  ),
                ],
              ),
            ),
          ),
          // Jump bar — positioned at bottom center
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _buildJumpBar(),
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _JumpButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

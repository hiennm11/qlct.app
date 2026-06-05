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
import 'backup_restore_screen.dart';

/// Main home screen for the expense tracking app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _transactionListKey = GlobalKey();

  // ignore: unused_element - Will be used when StatsWidget callbacks are implemented
  void _scrollToTransactions() {
    Scrollable.ensureVisible(
      _transactionListKey.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Xuất CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: ListTile(
                  leading: Icon(Icons.data_object),
                  title: Text('Xuất JSON'),
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
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ExpenseViewModel>().refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Quick add bar
              const QuickAddBar(),
              const SizedBox(height: 20),

              // Budget overview
              const BudgetOverviewWidget(),
              const SizedBox(height: 20),

              // Transactions list
              Container(
                key: _transactionListKey,
                child: const TransactionListWidget(),
              ),
              const SizedBox(height: 20),

              // Stats section
              // TODO(Phase 2): Add onTapToday, onTapWeek, onTapMonth callbacks
              const StatsWidget(),
              const SizedBox(height: 20),

              // Chart
              const ChartWidget(),
              const SizedBox(height: 20),

              // Recurring transactions
              const RecurringOverviewWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

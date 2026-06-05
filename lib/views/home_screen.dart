import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qlct/widgets/quick_voice_button.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/recurring_viewmodel.dart';
import '../widgets/stats_widget.dart';
import '../widgets/quick_input_widget.dart';
import '../widgets/custom_input_widget.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/chart_widget.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/recurring_overview_widget.dart';
import 'backup_restore_screen.dart';

/// Main home screen for the expense tracking app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Quản Lý Chi Tiêu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Sao lưu & Khôi phục',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BackupRestoreScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ExpenseViewModel>().refresh();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats section
            const StatsWidget(),
            const SizedBox(height: 20),

            // Budget overview
            const BudgetOverviewWidget(),
            const SizedBox(height: 20),

            // Recurring transactions
            const RecurringOverviewWidget(),
            const SizedBox(height: 20),

            const QuickVoiceButton(),
            const SizedBox(height: 12),

            // Quick input
            const QuickInputWidget(),
            const SizedBox(height: 20),

            // Custom input
            const CustomInputWidget(),
            const SizedBox(height: 20),

            // Transactions list
            const TransactionListWidget(),
            const SizedBox(height: 20),

            // Chart
            const ChartWidget(),
          ],
        ),
      ),
    );
  }
}

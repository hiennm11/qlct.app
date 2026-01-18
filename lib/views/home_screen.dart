import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../widgets/stats_widget.dart';
import '../widgets/quick_input_widget.dart';
import '../widgets/custom_input_widget.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/chart_widget.dart';

/// Main home screen for the expense tracking app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Quản Lý Chi Tiêu'),
        actions: [
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
            const SizedBox(height: 16),

            // Chart
            const ChartWidget(),

            // Quick input
            const QuickInputWidget(),
            const SizedBox(height: 16),

            // Custom input
            const CustomInputWidget(),
            const SizedBox(height: 16),

            // Transactions list
            const TransactionListWidget(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

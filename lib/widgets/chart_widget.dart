import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense_stats.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import 'section_header.dart';

/// Widget displaying expense chart by category
class ChartWidget extends StatefulWidget {
  const ChartWidget({super.key});

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  // ADR-0017 D5.2: memoize PieChart sections. The fl_chart PieChart rebuilds
  // and re-layouts every section on every build; recomputing them on each
  // ExpenseViewModel notification is wasted work when stats haven't changed.
  ExpenseStats? _lastStats;
  List<PieChartSectionData>? _cachedSections;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseViewModel>(
      builder: (context, viewModel, child) {
        final stats = viewModel.stats;
        final categoryTotals = stats.categoryTotals;

        if (viewModel.isLoading && viewModel.allTransactions.isEmpty) {
          // Loading state — drop any cached sections since data is stale.
          _lastStats = null;
          _cachedSections = null;
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (categoryTotals.isEmpty) {
          _lastStats = null;
          _cachedSections = null;
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📊', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 8),
                    Text(
                      'Chưa có dữ liệu để hiển thị',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Recompute sections only when stats instance changes.
        if (_cachedSections == null || !identical(_lastStats, stats)) {
          _cachedSections = _createSections(categoryTotals);
          _lastStats = stats;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(emoji: '📊', title: 'Chi tiêu theo danh mục'),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: _cachedSections!,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Legend(categoryTotals: categoryTotals),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _createSections(Map<String, int> categoryTotals) {
    final total = categoryTotals.values.fold(0, (sum, val) => sum + val);
    final colors = AppColors.categoryColors;

    int colorIndex = 0;
    return categoryTotals.entries.map((entry) {
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '$percentage%',
        color: color,
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

class _Legend extends StatelessWidget {
  final Map<String, int> categoryTotals;

  const _Legend({required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.categoryColors;

    int colorIndex = 0;
    return ListView(
      shrinkWrap: true,
      children: categoryTotals.entries.map((entry) {
        final color = colors[colorIndex % colors.length];
        colorIndex++;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      CurrencyFormatter.format(entry.value),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

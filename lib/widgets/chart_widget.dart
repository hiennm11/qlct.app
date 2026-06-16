import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense_stats.dart';
import '../models/category.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/theme.dart';
import '../core/formatters.dart';

/// Widget displaying expense chart by category.
///
/// ADR-0036: stats are keyed by `categoryId`. This widget takes a
/// pre-resolved `List<Category>` from the parent and maps id → display
/// (name, emoji, color). Same categoryId always gets the same color via
/// `id.hashCode.abs() % palette.length`.
///
/// ADR-0070: bug fix — (a) SizedBox 250→280 + wrap legend in
/// SingleChildScrollView để fix RenderFlex overflow dọc, (b) drop inline
/// PieChartSectionData.title (%) để fix label bị cắt/chồng trong slice
/// nhỏ — % chuyển vào legend row.
///
/// ADR-0074: layout redesign — replace side-by-side `Row` (pie 2x + scroll
/// legend) với vertical stack: PieChart on top (LayoutBuilder, max 200×200,
/// 1:1 aspect, centered) + 2-col `Wrap` legend bên dưới. Host
/// `budget_hub_screen.dart` constraint bump 220→360. Trade-off: 5–8 cats
/// fit in 3–4 rows, predictable height; 12+ stress edge documented.
class ChartWidget extends StatefulWidget {
  final List<Category> activeCategories;

  const ChartWidget({super.key, required this.activeCategories});

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  // ADR-0017 D5.2: memoize PieChart sections. The fl_chart PieChart rebuilds
  // and re-layouts every section on every build; recomputing them on each
  // ExpenseViewModel notification is wasted work when stats haven't changed.
  ExpenseStats? _lastStats;
  List<Category>? _lastCategories;
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
          _lastCategories = null;
          _cachedSections = null;
          return const Card(
            key: Key('chart-loading'),
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
          _lastCategories = null;
          _cachedSections = null;
          return const Card(
            key: Key('chart-empty'),
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

        // Recompute sections only when stats or active categories change.
        if (_cachedSections == null ||
            !identical(_lastStats, stats) ||
            !identical(_lastCategories, widget.activeCategories)) {
          _cachedSections = _createSections(categoryTotals, widget.activeCategories);
          _lastStats = stats;
          _lastCategories = widget.activeCategories;
        }

        return Card(
          key: const Key('chart-loaded'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bug A v2 (ADR-0070 §3 update 2026-06-16): SectionHeader
                // bị duplicate với '📊 Biểu đồ danh mục' manual header ở
                // budget_hub_screen.dart:78-93. Host screen đã render title
                // rồi, ChartWidget chỉ render chart + legend.
                //
                // ADR-0074: vertical stack layout — pie chart on top
                // (LayoutBuilder caps at min(maxWidth, 180) for 1:1 aspect),
                // legend 2-col Wrap bên dưới. Replaces ADR-0070 §2 side-by-side
                // Row (pie flex 2 + scroll legend) which overflowed 220px host
                // constraint in budget_hub_screen.dart. Pie 180 (was 200 in
                // plan sketch) để fit 4 rows legend + Card padding trong 400
                // host budget.
                LayoutBuilder(
                  builder: (context, c) {
                    final pieSize = c.maxWidth < 180 ? c.maxWidth : 180.0;
                    return Center(
                      child: SizedBox(
                        width: pieSize,
                        height: pieSize,
                        child: PieChart(
                          PieChartData(
                            sections: _cachedSections!,
                            centerSpaceRadius: pieSize * 0.2,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _LegendGrid(
                  categoryTotals: categoryTotals,
                  activeCategories: widget.activeCategories,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _createSections(
    Map<String, int> categoryTotals,
    List<Category> activeCategories,
  ) {
    final colors = AppColors.categoryColors;

    return categoryTotals.entries.map((entry) {
      // ADR-0036: deterministic color by categoryId hash. Same id always
      // gets the same color regardless of iteration order.
      final color = colors[entry.key.hashCode.abs() % colors.length];

      return PieChartSectionData(
        value: entry.value.toDouble(),
        // ADR-0070 §3 fix: PHẢI set showTitle=false.
        // fl_chart default: title = value.toString() (raw amount) khi title null.
        // Bug pre-fix: slice vẫn hiển thị "12000000.0", "34000.0" vì fl_chart
        // tự sinh title từ value. Drop title thôi không đủ — phải tắt showTitle.
        showTitle: false,
        color: color,
        radius: 80,
      );
    }).toList();
  }
}

class _LegendGrid extends StatelessWidget {
  final Map<String, int> categoryTotals;
  final List<Category> activeCategories;

  const _LegendGrid({
    required this.categoryTotals,
    required this.activeCategories,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.categoryColors;
    final categoriesById = {for (final c in activeCategories) c.id: c};
    final total =
        categoryTotals.values.fold<int>(0, (sum, val) => sum + val);

    // ADR-0074: 2-col Wrap grid. LayoutBuilder computes cell width =
    // (maxWidth - spacing) / 2. Wrap flow tự động scale với category count:
    // 5-8 cats → 3-4 rows, 12+ cats → 6+ rows (overflow host, documented).
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 8.0;
        final cellW = (c.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: categoryTotals.entries.map((entry) {
            // ADR-0036: stable color by id hash, name from catalog.
            final color = colors[entry.key.hashCode.abs() % colors.length];
            final cat = categoriesById[entry.key];
            final displayName = cat?.name ?? 'Khác';
            final emoji = cat?.emoji ?? '📌';
            // ADR-0070 §3: % inline cạnh amount.
            final percentage = total > 0
                ? (entry.value / total * 100).toStringAsFixed(1)
                : '0.0';

            return SizedBox(
              width: cellW,
              child: Padding(
                key: Key('legend-row-${entry.key}'),
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
                            '$emoji $displayName',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$percentage% · ${CurrencyFormatter.format(entry.value)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

import '../models/budget.dart';
import '../models/budget_plan.dart';
import '../models/category.dart';
import '../models/monthly_budget_plan_data.dart';
import '../models/transaction.dart';

/// Source values for [MonthlyBudgetPlanBuilder.buildDraft].
const kBudgetPlanSourcePreviousMonth = 'previousMonth';
const kBudgetPlanSourceCurrentBudget = 'currentBudget';
const kBudgetPlanSourceEmpty = 'empty';

const _kValidSources = {
  kBudgetPlanSourcePreviousMonth,
  kBudgetPlanSourceCurrentBudget,
  kBudgetPlanSourceEmpty,
};
const kMaxRecentCompletedMonths = 3;

/// Pure deterministic builder for monthly budget planning draft.
///
/// No DataSource, no ChangeNotifier, no side effects.
/// All computation is deterministic given the same inputs.
///
/// ADR-0026: Monthly Budget Planning
class MonthlyBudgetPlanBuilder {
  /// Build a planning draft for [targetMonth].
  ///
  /// [source] — initialization source: must be one of
  ///   `kBudgetPlanSourcePreviousMonth` | `kBudgetPlanSourceCurrentBudget`
  ///   | `kBudgetPlanSourceEmpty`. Throws [ArgumentError] otherwise.
  /// [baseBudgets] — source-selected base budgets for `baseLimit` and `alertThreshold`.
  /// [previousMonthBudgets] — for over-budget detection.
  /// [liveTotalBudget] — current live total budget (used in `currentBudget` and
  ///   `previousMonth` source defaults for `plannedTotalBudget`).
  /// [recentCompletedMonthTransactions] — up to [kMaxRecentCompletedMonths]
  ///   completed months of transactions, used to compute `suggestedLimit`.
  ///   Absent category in a supplied month counts as 0.
  ///   Throws [ArgumentError] when length exceeds the cap.
  /// [previousMonthTransactions] — last completed month transactions, used to
  ///   compute `lastMonthSpent` and `wasOverBudgetLastMonth`.
  /// [now] — clock for `createdAt` / `updatedAt`. Required so the builder is
  ///   deterministic; callers in tests pass a fixed value.
  MonthlyBudgetPlanData buildDraft({
    required DateTime targetMonth,
    required String source,
    required List<Budget> baseBudgets,
    required List<Budget> previousMonthBudgets,
    required int? liveTotalBudget,
    required List<List<Transaction>> recentCompletedMonthTransactions,
    required List<Transaction> previousMonthTransactions,
    required DateTime now,
  }) {
    if (!_kValidSources.contains(source)) {
      throw ArgumentError.value(
        source,
        'source',
        'must be one of ${_kValidSources.join(' | ')}',
      );
    }
    if (recentCompletedMonthTransactions.length > kMaxRecentCompletedMonths) {
      throw ArgumentError.value(
        recentCompletedMonthTransactions,
        'recentCompletedMonthTransactions',
        'max length is $kMaxRecentCompletedMonths',
      );
    }

    final timestamp = now;
    final yearMonth = _formatYearMonth(targetMonth);

    final baseMap = {for (final b in baseBudgets) b.categoryName: b};
    final previousMap = {
      for (final b in previousMonthBudgets) b.categoryName: b
    };

    // lastMonthSpent aggregated per non-investment category
    final lastMonthSpentMap = <String, int>{};
    for (final tx in previousMonthTransactions) {
      if (_isInvestment(tx.category)) continue;
      lastMonthSpentMap[tx.category] =
          (lastMonthSpentMap[tx.category] ?? 0) + tx.amount;
    }

    // Recent months spending per category (newest first, up to 3)
    final recentMonthSpends = <String, List<int>>{};
    for (final monthTxs in recentCompletedMonthTransactions) {
      final monthByCategory = <String, int>{};
      for (final tx in monthTxs) {
        if (_isInvestment(tx.category)) continue;
        monthByCategory[tx.category] =
            (monthByCategory[tx.category] ?? 0) + tx.amount;
      }
      for (final cat in Category.predefined.where((c) => !c.isInvestment)) {
        (recentMonthSpends[cat.name] ??= []).add(monthByCategory[cat.name] ?? 0);
      }
    }

    final items = <BudgetPlanItem>[];
    for (final cat in Category.predefined) {
      if (cat.isInvestment) continue;

      final base = baseMap[cat.name];
      final previous = previousMap[cat.name];
      final baseLimit = base?.monthlyLimit ?? 0;
      final previousBudgetLimit = previous?.monthlyLimit ?? 0;
      final lastMonthSpent = lastMonthSpentMap[cat.name] ?? 0;
      final wasOverBudgetLastMonth = previousBudgetLimit > 0 &&
          lastMonthSpent > previousBudgetLimit;

      final months = recentMonthSpends[cat.name] ?? const <int>[];
      final suggestedRaw = _computeSuggestion(months);
      final suggested = _roundSuggestion(suggestedRaw);

      final recommendation = _classify(
        suggested: suggested,
        baseLimit: baseLimit,
        wasOverBudgetLastMonth: wasOverBudgetLastMonth,
      );

      final plannedLimit = _initialPlannedLimit(
        source: source,
        suggested: suggested,
        baseLimit: baseLimit,
      );

      final alertThreshold = base?.alertThreshold ??
          previous?.alertThreshold ??
          80;

      items.add(BudgetPlanItem(
        yearMonth: yearMonth,
        categoryName: cat.name,
        plannedLimit: plannedLimit,
        alertThreshold: alertThreshold,
        suggestedLimit: suggested,
        baseLimit: baseLimit,
        lastMonthSpent: lastMonthSpent,
        wasOverBudgetLastMonth: wasOverBudgetLastMonth,
        recommendation: recommendation,
      ));
    }

    final sumPlanned = items.fold<int>(0, (s, i) => s + i.plannedLimit);
    final plannedTotalBudget = _plannedTotalBudget(
      source: source,
      sumPlanned: sumPlanned,
      liveTotalBudget: liveTotalBudget,
    );

    final plan = BudgetPlan(
      yearMonth: yearMonth,
      plannedTotalBudget: plannedTotalBudget,
      source: source,
      status: 'draft',
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final keep = <BudgetPlanItem>[];
    final increase = <BudgetPlanItem>[];
    final decrease = <BudgetPlanItem>[];
    for (final item in items) {
      switch (item.recommendation) {
        case 'increase':
          increase.add(item);
          break;
        case 'decrease':
          decrease.add(item);
          break;
        default:
          keep.add(item);
      }
    }

    return MonthlyBudgetPlanData(
      plan: plan,
      items: items,
      keepItems: keep,
      increaseItems: increase,
      decreaseItems: decrease,
      allocatedAmount: sumPlanned,
      activeCategoryCount: items.where((i) => i.plannedLimit > 0).length,
    );
  }

  int _computeSuggestion(List<int> months) {
    if (months.isEmpty) return 0;
    if (months.length == 1) return months[0];
    if (months.length == 2) {
      final sum = months[0] + months[1];
      final avg = sum / 2;
      return avg.round();
    }
    // 3 months -> median
    final sorted = [...months]..sort();
    return sorted[1];
  }

  int _roundSuggestion(int value) {
    if (value <= 0) return 0;
    if (value < 1000000) {
      final step = 50000;
      return ((value + step - 1) ~/ step) * step;
    }
    final step = 100000;
    return ((value + step - 1) ~/ step) * step;
  }

  String _classify({
    required int suggested,
    required int baseLimit,
    required bool wasOverBudgetLastMonth,
  }) {
    if (wasOverBudgetLastMonth) return 'increase';
    if (baseLimit == 0) {
      if (suggested > 0) return 'increase';
      return 'keep';
    }
    // Exact int comparisons: increase if suggested*100 >= baseLimit*115,
    // decrease if suggested*100 <= baseLimit*85.
    final suggested100 = suggested * 100;
    final increaseThreshold = baseLimit * 115;
    final decreaseThreshold = baseLimit * 85;
    if (suggested100 >= increaseThreshold) return 'increase';
    if (suggested100 <= decreaseThreshold) return 'decrease';
    return 'keep';
  }

  int _initialPlannedLimit({
    required String source,
    required int suggested,
    required int baseLimit,
  }) {
    if (source == kBudgetPlanSourceEmpty) return suggested;
    return suggested > 0 ? suggested : baseLimit;
  }

  int _plannedTotalBudget({
    required String source,
    required int sumPlanned,
    required int? liveTotalBudget,
  }) {
    switch (source) {
      case kBudgetPlanSourceCurrentBudget:
        return liveTotalBudget ?? sumPlanned;
      case kBudgetPlanSourcePreviousMonth:
        final live = liveTotalBudget ?? 0;
        return live > sumPlanned ? live : sumPlanned;
      case kBudgetPlanSourceEmpty:
      default:
        return sumPlanned;
    }
  }

  bool _isInvestment(String categoryName) {
    final cat = Category.predefined
        .where((c) => c.name == categoryName)
        .firstOrNull;
    return cat?.isInvestment ?? false;
  }

  String _formatYearMonth(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year}-$m';
  }
}

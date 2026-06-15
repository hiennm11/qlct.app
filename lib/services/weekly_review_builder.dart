import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/weekly_review_data.dart';

/// Pure deterministic aggregator for weekly review analytics.
/// No DataSource, no ChangeNotifier, no side effects.
/// All computation is deterministic given the same inputs.
///
/// ADR-0053: Weekly Review Card on Home (Epic 4)
class WeeklyReviewBuilder {
  /// Build WeeklyReviewData from raw inputs.
  ///
  /// [currentWeekTransactions] — all transactions in current week range
  /// [previousCompareTransactions] — transactions in previous comparable range
  ///   (same-period for current week in progress, full previous week for past)
  /// [budgets] — current month budget config (for budgetRisk)
  /// [activeRecurring] — all active recurring rules (for upcomingRecurringCount)
  /// [categories] — full category catalog (for orphan-id filter and lookup)
  /// [currentWeekStart] / [currentWeekEnd] — Mon 00:00 → Sun 23:59 (or now)
  /// [previousCompareStart] / [previousCompareEnd] — same-period previous range
  /// [now] — current wall clock (for upcoming recurring window)
  WeeklyReviewData build({
    required List<Transaction> currentWeekTransactions,
    required List<Transaction> previousCompareTransactions,
    required List<Budget> budgets,
    required List<RecurringTransaction> activeRecurring,
    required List<Category> categories,
    required DateTime currentWeekStart,
    required DateTime currentWeekEnd,
    required DateTime previousCompareStart,
    required DateTime previousCompareEnd,
    required DateTime now,
  }) {
    // ADR-0036: drop orphan ids (tx whose categoryId is not in the
    // catalog) at the source. Orphans are unrenderable data.
    final categoryIds = {for (final c in categories) c.id};
    bool isOrphan(Transaction t) =>
        t.categoryId.isNotEmpty && !categoryIds.contains(t.categoryId);

    final currentFiltered =
        currentWeekTransactions.where((t) => !isOrphan(t)).toList();
    final previousFiltered =
        previousCompareTransactions.where((t) => !isOrphan(t)).toList();

    // Categories by id (ADR-0036) + kind lookup
    final categoriesById = {for (final c in categories) c.id: c};
    bool isInvestmentCategoryId(String id) {
      final c = categoriesById[id];
      return c != null && c.kind == CategoryKind.investment;
    }

    // Spending vs investment (weekSpent = spending only, mirror ADR-0021)
    final currentSpending = currentFiltered
        .where((t) => !isInvestmentCategoryId(t.categoryId))
        .toList();
    final previousSpending = previousFiltered
        .where((t) => !isInvestmentCategoryId(t.categoryId))
        .toList();

    final weekSpent =
        currentSpending.fold(0, (sum, t) => sum + t.amount);
    final prevWeekSpent =
        previousSpending.fold(0, (sum, t) => sum + t.amount);
    final spendingDelta = weekSpent - prevWeekSpent;

    // Low-data state (spending only, mirror Monthly Review)
    final WeeklyReviewLowDataState lowDataState;
    if (currentSpending.isEmpty) {
      lowDataState = WeeklyReviewLowDataState.empty;
    } else if (currentSpending.length < 3) {
      lowDataState = WeeklyReviewLowDataState.low;
    } else {
      lowDataState = WeeklyReviewLowDataState.normal;
    }

    // hasEnoughDataForDelta: cần prev week data + current week có gì đó
    final hasEnoughDataForDelta =
        prevWeekSpent > 0 && weekSpent > 0;

    // Top category delta (spending only, by categoryId per ADR-0036)
    final topCategoryResult = _computeTopCategoryDelta(
      currentSpending: currentSpending,
      previousSpending: previousSpending,
      categoriesById: categoriesById,
    );

    // Days logged (spending only, distinct date count, max 7)
    final daysLogged = _computeDaysLogged(currentSpending);

    // Largest transaction (ALL categories incl. investment — grill Q4)
    final largestTransaction = _computeLargestTransaction(currentFiltered);

    // Budget risk (spending + flexible/fixed only, threshold 80% + 100%)
    final budgetRiskIds = _computeBudgetRiskCategoryIds(
      spending: currentSpending,
      budgets: budgets,
      categories: categories,
      categoriesById: categoriesById,
    );

    // Upcoming recurring (next 7 days from now, all active rules)
    final upcomingRecurringCount = _computeUpcomingRecurringCount(
      activeRecurring: activeRecurring,
      now: now,
    );

    return WeeklyReviewData(
      currentWeekStart: currentWeekStart,
      currentWeekEnd: currentWeekEnd,
      previousCompareStart: previousCompareStart,
      previousCompareEnd: previousCompareEnd,
      weekSpent: weekSpent,
      prevWeekSpent: prevWeekSpent,
      spendingDelta: spendingDelta,
      topCategoryId: topCategoryResult?.categoryId,
      topCategoryDelta: topCategoryResult?.deltaVnd ?? 0,
      topCategoryCurrentSpent: topCategoryResult?.currentAmount ?? 0,
      topCategoryPrevSpent: topCategoryResult?.previousAmount ?? 0,
      topCategoryNewlyIncurred: topCategoryResult?.isNewlyIncurred ?? false,
      daysLogged: daysLogged,
      largestTransaction: largestTransaction,
      budgetRiskCategoryIds: budgetRiskIds,
      upcomingRecurringCount: upcomingRecurringCount,
      hasEnoughDataForDelta: hasEnoughDataForDelta,
      lowDataState: lowDataState,
    );
  }

  /// Find category with biggest absolute VND delta (current - previous).
  /// Returns null nếu cả 2 đều rỗng hoặc tất cả category đều 0.
  _TopCategoryResult? _computeTopCategoryDelta({
    required List<Transaction> currentSpending,
    required List<Transaction> previousSpending,
    required Map<String, Category> categoriesById,
  }) {
    final currentTotals = <String, int>{};
    final previousTotals = <String, int>{};

    for (final tx in currentSpending) {
      final id = tx.categoryId;
      if (id.isEmpty) continue;
      if (!categoriesById.containsKey(id)) continue;
      currentTotals[id] = (currentTotals[id] ?? 0) + tx.amount;
    }
    for (final tx in previousSpending) {
      final id = tx.categoryId;
      if (id.isEmpty) continue;
      if (!categoriesById.containsKey(id)) continue;
      previousTotals[id] = (previousTotals[id] ?? 0) + tx.amount;
    }

    final allIds = {...currentTotals.keys, ...previousTotals.keys};
    if (allIds.isEmpty) return null;

    _TopCategoryResult? best;
    int bestAbsDelta = 0;

    for (final id in allIds) {
      final current = currentTotals[id] ?? 0;
      final previous = previousTotals[id] ?? 0;
      final delta = current - previous;
      final absDelta = delta.abs();
      if (absDelta > bestAbsDelta) {
        bestAbsDelta = absDelta;
        best = _TopCategoryResult(
          categoryId: id,
          currentAmount: current,
          previousAmount: previous,
          deltaVnd: delta,
          isNewlyIncurred: previous == 0 && current > 0,
        );
      }
    }

    return best;
  }

  /// Count distinct dates with at least 1 spending transaction (capped 0-7).
  int _computeDaysLogged(List<Transaction> spendingTxs) {
    if (spendingTxs.isEmpty) return 0;
    final days = <String>{};
    for (final tx in spendingTxs) {
      days.add(_dayKey(tx.date));
    }
    return days.length.clamp(0, 7);
  }

  /// Find largest transaction by amount, across all categories (incl. investment).
  /// Returns null nếu tuần rỗng.
  WeeklyReviewLargestTransaction? _computeLargestTransaction(
    List<Transaction> allTxs,
  ) {
    if (allTxs.isEmpty) return null;
    Transaction? max;
    for (final tx in allTxs) {
      if (max == null || tx.amount > max.amount) {
        max = tx;
      }
    }
    if (max == null) return null;
    return WeeklyReviewLargestTransaction(
      amount: max.amount,
      categoryId: max.categoryId,
      date: DateTime(max.date.year, max.date.month, max.date.day),
    );
  }

  /// Categories at warning (≥80%) or exceeded (≥100%) budget status.
  /// Exclude investment (ADR-0025 §6).
  List<String> _computeBudgetRiskCategoryIds({
    required List<Transaction> spending,
    required List<Budget> budgets,
    required List<Category> categories,
    required Map<String, Category> categoriesById,
  }) {
    final categoryTotals = <String, int>{};
    for (final tx in spending) {
      final id = tx.categoryId;
      if (id.isEmpty) continue;
      if (!categoriesById.containsKey(id)) continue;
      categoryTotals[id] = (categoryTotals[id] ?? 0) + tx.amount;
    }

    final budgetMap = {for (var b in budgets) b.categoryId: b};
    final riskIds = <String>[];

    for (final category in categories) {
      if (category.kind == CategoryKind.investment) continue;
      final budget = budgetMap[category.id];
      if (budget == null) continue;
      final spent = categoryTotals[category.id] ?? 0;
      final limit = budget.monthlyLimit;
      if (limit <= 0) continue;
      final percentUsed = (spent / limit) * 100;
      if (percentUsed >= budget.alertThreshold) {
        riskIds.add(category.id);
      }
    }

    return riskIds;
  }

  /// Count active recurring rules với nextRunAt ∈ [now, now+7d].
  int _computeUpcomingRecurringCount({
    required List<RecurringTransaction> activeRecurring,
    required DateTime now,
  }) {
    final horizon = now.add(const Duration(days: 7));
    var count = 0;
    for (final r in activeRecurring) {
      if (!r.isActive) continue;
      if (r.nextRunAt.isAfter(now) && r.nextRunAt.isBefore(horizon)) {
        count++;
      }
    }
    return count;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _TopCategoryResult {
  final String categoryId;
  final int currentAmount;
  final int previousAmount;
  final int deltaVnd;
  final bool isNewlyIncurred;
  _TopCategoryResult({
    required this.categoryId,
    required this.currentAmount,
    required this.previousAmount,
    required this.deltaVnd,
    required this.isNewlyIncurred,
  });
}

import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/monthly_review_data.dart';

/// Pure deterministic aggregator for monthly review analytics.
/// No DataSource, no ChangeNotifier, no side effects.
/// All computation is deterministic given the same inputs.
///
/// ADR-0021: Monthly Review as Read-only Derived Analytics
class MonthlyReviewBuilder {
  /// Build MonthlyReviewData from raw inputs.
  ///
  /// [currentMonthTxs] — all transactions in selected month
  /// [previousPeriodTxs] — transactions in comparable previous period
  /// [budgets] — current budget config (used for past month snapshot)
  /// [activeRecurringRules] — only shown when selected month is current month
  /// [selectedMonth] — the month being reviewed
  /// [currentPeriodStart], [currentPeriodEnd] — selected period bounds
  /// [previousPeriodStart], [previousPeriodEnd] — previous comparable period
  MonthlyReviewData build({
    required List<Transaction> currentMonthTxs,
    required List<Transaction> previousPeriodTxs,
    required List<Budget> budgets,
    required List<RecurringTransaction> activeRecurringRules,
    required List<Category> categories,
    required DateTime selectedMonth,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    required DateTime previousPeriodStart,
    required DateTime previousPeriodEnd,
    Map<String, int> carryByCategoryId = const {},
  }) {
    bool isCatInvestment(String name) {
      for (final c in categories) {
        if (c.name == name) return c.kind == CategoryKind.investment;
      }
      return false;
    }

    // ADR-0036: drop orphan ids (tx whose categoryId is not in the
    // catalog) at the source. Orphans are unrenderable data — the
    // category was deleted but the transaction still exists. They
    // must not drive any aggregate, including the spending total.
    final categoryIds = {for (final c in categories) c.id};
    bool isOrphan(Transaction t) =>
        t.categoryId.isNotEmpty && !categoryIds.contains(t.categoryId);

    final currentMonthTxsFiltered =
        currentMonthTxs.where((t) => !isOrphan(t)).toList();
    final previousPeriodTxsFiltered =
        previousPeriodTxs.where((t) => !isOrphan(t)).toList();

    // Separate spending vs investment
    final currentSpending = currentMonthTxsFiltered
        .where((t) => !isCatInvestment(t.category))
        .toList();
    final currentInvestment = currentMonthTxsFiltered
        .where((t) => isCatInvestment(t.category))
        .toList();

    final previousSpending = previousPeriodTxsFiltered
        .where((t) => !isCatInvestment(t.category))
        .toList();

    final spendingTotal = currentSpending.fold(0, (sum, t) => sum + t.amount);
    final investmentTotal = currentInvestment.fold(0, (sum, t) => sum + t.amount);
    final totalOutflow = spendingTotal + investmentTotal;
    final previousSpendingTotal = previousSpending.fold(0, (sum, t) => sum + t.amount);
    final spendingDelta = spendingTotal - previousSpendingTotal;

    // Category summaries (exclude investment)
    final topCategories = _buildTopCategories(currentSpending, spendingTotal, categories);
    final remainingCategoryTotal = _computeRemainingCategoryTotal(currentSpending, topCategories);

    // Biggest increase/decrease
    final hasEnoughData = currentSpending.length >= 3;
    final biggestIncrease = _buildBiggestDelta(
      currentSpending, previousSpending,
      categories: categories,
      positive: true,
    );
    final biggestDecrease = _buildBiggestDelta(
      currentSpending, previousSpending,
      categories: categories,
      positive: false,
    );

    // Fixed expense summary
    final fixedExpenseSummary = _buildFixedExpenseSummary(
      currentMonthTxsFiltered,
      activeRecurringRules,
      categories,
    );

    // Budget highlights (ADR-0025 §6: skip investment categories)
    final budgetHighlights = _buildBudgetHighlights(currentSpending, budgets, categories, carryByCategoryId);

    // Biggest spending day (only from spending, exclude investment)
    final biggestSpendingDay = _buildBiggestSpendingDay(currentSpending);

    return MonthlyReviewData(
      selectedMonth: selectedMonth,
      currentPeriodStart: currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd,
      previousPeriodStart: previousPeriodStart,
      previousPeriodEnd: previousPeriodEnd,
      totalOutflow: totalOutflow,
      spendingTotal: spendingTotal,
      investmentTotal: investmentTotal,
      previousSpendingTotal: previousSpendingTotal,
      spendingDelta: spendingDelta,
      topCategories: topCategories,
      remainingCategoryTotal: remainingCategoryTotal,
      biggestIncrease: biggestIncrease,
      biggestDecrease: biggestDecrease,
      fixedExpenseSummary: fixedExpenseSummary,
      budgetHighlights: budgetHighlights,
      biggestSpendingDay: biggestSpendingDay,
      hasEnoughDataForDelta: hasEnoughData,
    );
  }

  List<MonthlyReviewCategorySummary> _buildTopCategories(
    List<Transaction> spendingTxs,
    int totalSpending,
    List<Category> categories,
  ) {
    // ADR-0036: group by categoryId, not display name. Skip ids that
    // do not exist in the supplied categories catalog (orphan ids).
    final categoriesById = {for (final c in categories) c.id: c};
    final categoryTotals = <String, int>{};
    for (final tx in spendingTxs) {
      final id = tx.categoryId;
      if (id.isEmpty) continue;
      if (!categoriesById.containsKey(id)) continue; // orphan, skip
      categoryTotals[id] = (categoryTotals[id] ?? 0) + tx.amount;
    }

    // Sort by amount descending, take top 5
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();

    return top5.map((entry) {
      final cat = categoriesById[entry.key]!;
      final percent = totalSpending > 0
          ? ((entry.value / totalSpending) * 100).round()
          : 0;
      return MonthlyReviewCategorySummary(
        categoryName: cat.name,
        emoji: cat.emoji,
        amount: entry.value,
        percentOfSpending: percent,
      );
    }).toList();
  }

  int _computeRemainingCategoryTotal(
    List<Transaction> spendingTxs,
    List<MonthlyReviewCategorySummary> topCategories,
  ) {
    final topTotal = topCategories.fold(0, (sum, c) => sum + c.amount);
    final allTotal = spendingTxs.fold(0, (sum, t) => sum + t.amount);
    return allTotal - topTotal;
  }

  MonthlyReviewCategoryDelta? _buildBiggestDelta(
    List<Transaction> currentSpending,
    List<Transaction> previousSpending, {
    required List<Category> categories,
    required bool positive,
  }) {
    // ADR-0036: group by categoryId, skip orphan ids.
    final currentTotals = <String, int>{};
    final previousTotals = <String, int>{};
    final categoriesById = {for (final c in categories) c.id: c};

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

    // Find all categoryIds in either period
    final allIds = {...currentTotals.keys, ...previousTotals.keys};

    // Compute deltas
    final deltas = <_DeltaEntry>[];
    for (final id in allIds) {
      final current = currentTotals[id] ?? 0;
      final previous = previousTotals[id] ?? 0;
      final deltaVnd = current - previous;
      final isNewlyIncurred = previous == 0 && current > 0;
      final displayName = categoriesById[id]?.name ?? 'Khác';

      // Calculate percent (handle division by zero)
      double deltaPercent;
      if (previous == 0) {
        deltaPercent = 0; // will be flagged as newlyIncurred
      } else {
        deltaPercent = ((current - previous) / previous) * 100;
      }

      deltas.add(_DeltaEntry(
        categoryName: displayName,
        currentAmount: current,
        previousAmount: previous,
        deltaVnd: deltaVnd,
        deltaPercent: deltaPercent,
        isNewlyIncurred: isNewlyIncurred,
      ));
    }

    if (deltas.isEmpty) return null;

    // Sort by absolute delta for biggest increase/decrease
    if (positive) {
      deltas.sort((a, b) => b.deltaVnd.compareTo(a.deltaVnd));
    } else {
      deltas.sort((a, b) => a.deltaVnd.compareTo(b.deltaVnd));
    }

    final best = deltas.first;
    if (best.currentAmount == 0 && best.previousAmount == 0) return null;

    final cat = categories
        .where((c) => c.name == best.categoryName)
        .firstOrNull;

    return MonthlyReviewCategoryDelta(
      categoryName: best.categoryName,
      emoji: cat?.emoji ?? '📌',
      currentAmount: best.currentAmount,
      previousAmount: best.previousAmount,
      deltaVnd: best.deltaVnd,
      deltaPercent: best.deltaPercent,
      isNewlyIncurred: best.isNewlyIncurred,
    );
  }

  MonthlyReviewFixedExpenseSummary _buildFixedExpenseSummary(
    List<Transaction> currentMonthTxs,
    List<RecurringTransaction> activeRecurringRules,
    List<Category> categories,
  ) {
    // Subscription category transactions
    final subscriptionTxs = currentMonthTxs
        .where((t) => t.category == 'Subscription')
        .toList();

    // Recurring-generated transactions (sourceRecurringId != null), exclude investment
    bool isCatInvestment(String name) {
      for (final c in categories) {
        if (c.name == name) return c.kind == CategoryKind.investment;
      }
      return false;
    }

    final recurringGeneratedTxs = currentMonthTxs
        .where((t) =>
            t.sourceRecurringId != null &&
            !isCatInvestment(t.category))
        .toList();

    // Union distinct by transaction.id
    final seen = <String>{};
    final union = <Transaction>[];
    for (final tx in [...subscriptionTxs, ...recurringGeneratedTxs]) {
      if (seen.add(tx.id)) {
        union.add(tx);
      }
    }

    final totalAmount = union.fold(0, (sum, t) => sum + t.amount);
    final subscriptionAmount = subscriptionTxs.fold(0, (sum, t) => sum + t.amount);
    final recurringGeneratedAmount = recurringGeneratedTxs.fold(0, (sum, t) => sum + t.amount);

    // Build items — subscription (exclude recurring-generated ones from here to avoid double count)
    final subscriptionItems = subscriptionTxs
        .where((t) => t.sourceRecurringId == null) // pure subscription, not recurring-generated
        .map((t) => MonthlyReviewFixedExpenseItem(
              transactionId: t.id,
              categoryName: t.category,
              emoji: t.emoji,
              amount: t.amount,
              date: t.date,
              note: t.note,
              isRecurringGenerated: false,
            ))
        .toList();

    // Recurring-generated items (non-investment)
    final recurringItems = recurringGeneratedTxs
        .map((t) => MonthlyReviewFixedExpenseItem(
              transactionId: t.id,
              categoryName: t.category,
              emoji: t.emoji,
              amount: t.amount,
              date: t.date,
              note: t.note,
              isRecurringGenerated: true,
            ))
        .toList();

    // Active recurring rules
    final activeRules = activeRecurringRules
        .where((r) => r.isActive)
        .map((r) {
          final cat = categories
              .where((c) => c.name == r.categoryName)
              .firstOrNull;
          return MonthlyReviewActiveRecurringRule(
            id: r.id,
            categoryName: r.categoryName,
            emoji: cat?.emoji ?? '📌',
            amount: r.amount,
            frequency: r.frequency,
          );
        })
        .toList();

    return MonthlyReviewFixedExpenseSummary(
      totalAmount: totalAmount,
      subscriptionAmount: subscriptionAmount,
      recurringGeneratedAmount: recurringGeneratedAmount,
      subscriptionItems: subscriptionItems,
      recurringGeneratedItems: recurringItems,
      activeRecurringRules: activeRules,
    );
  }

  List<MonthlyReviewBudgetHighlight> _buildBudgetHighlights(
    List<Transaction> currentSpending,
    List<Budget> budgets,
    List<Category> categories,
    Map<String, int> carryByCategoryId,
  ) {
    // ADR-0036: group spending by categoryId, not display name.
    // Orphan ids (not in the catalog) are silently dropped — they
    // have no budget to highlight and no category to render.
    final categoryTotals = <String, int>{};
    final categoriesById = {for (final c in categories) c.id: c};
    for (final tx in currentSpending) {
      final id = tx.categoryId;
      if (id.isEmpty) continue;
      if (!categoriesById.containsKey(id)) continue;
      categoryTotals[id] = (categoryTotals[id] ?? 0) + tx.amount;
    }

    final budgetMap = {for (var b in budgets) b.categoryId: b};
    final highlights = <MonthlyReviewBudgetHighlight>[];

    // ADR-0025 §6: skip investment categories in budget highlights
    for (final category in categories) {
      if (category.kind == CategoryKind.investment) continue;
      final budget = budgetMap[category.id];
      if (budget == null) continue;

      final spent = categoryTotals[category.id] ?? 0;
      final limit = budget.monthlyLimit;
      final percentUsed = limit > 0 ? ((spent / limit) * 100).round() : 0;
      final isExceeded = percentUsed >= 100;
      final isWarning = percentUsed >= budget.alertThreshold && !isExceeded;

      if (isExceeded || isWarning) {
        highlights.add(MonthlyReviewBudgetHighlight(
          categoryName: category.name,
          emoji: category.emoji,
          spent: spent,
          limit: limit,
          percentUsed: percentUsed,
          isExceeded: isExceeded,
          isWarning: isWarning,
          carryAmount: carryByCategoryId[category.id] ?? 0,
        ));
      }
    }

    // Sort: exceeded first, then warning, by percent descending
    highlights.sort((a, b) {
      if (a.isExceeded && !b.isExceeded) return -1;
      if (!a.isExceeded && b.isExceeded) return 1;
      return b.percentUsed.compareTo(a.percentUsed);
    });

    return highlights;
  }

  MonthlyReviewDaySummary? _buildBiggestSpendingDay(List<Transaction> spendingTxs) {
    if (spendingTxs.isEmpty) return null;

    // Group by date (day only)
    final dayTotals = <String, _DayEntry>{};
    for (final tx in spendingTxs) {
      final dayKey = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      final existing = dayTotals[dayKey];
      if (existing != null) {
        dayTotals[dayKey] = _DayEntry(
          date: tx.date,
          total: existing.total + tx.amount,
          count: existing.count + 1,
        );
      } else {
        dayTotals[dayKey] = _DayEntry(
          date: DateTime(tx.date.year, tx.date.month, tx.date.day),
          total: tx.amount,
          count: 1,
        );
      }
    }

    if (dayTotals.isEmpty) return null;

    // Find biggest
    final biggest = dayTotals.values.reduce((a, b) => a.total > b.total ? a : b);

    return MonthlyReviewDaySummary(
      date: biggest.date,
      totalAmount: biggest.total,
      transactionCount: biggest.count,
    );
  }
}

class _DeltaEntry {
  final String categoryName;
  final int currentAmount;
  final int previousAmount;
  final int deltaVnd;
  final double deltaPercent;
  final bool isNewlyIncurred;
  _DeltaEntry({
    required this.categoryName,
    required this.currentAmount,
    required this.previousAmount,
    required this.deltaVnd,
    required this.deltaPercent,
    required this.isNewlyIncurred,
  });
}

class _DayEntry {
  final DateTime date;
  final int total;
  final int count;
  _DayEntry({required this.date, required this.total, required this.count});
}
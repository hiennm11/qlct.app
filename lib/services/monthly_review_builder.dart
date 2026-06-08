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
    required DateTime selectedMonth,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    required DateTime previousPeriodStart,
    required DateTime previousPeriodEnd,
  }) {
    // Separate spending vs investment
    final currentSpending = currentMonthTxs
        .where((t) => !_isInvestment(t.category))
        .toList();
    final currentInvestment = currentMonthTxs
        .where((t) => _isInvestment(t.category))
        .toList();

    final previousSpending = previousPeriodTxs
        .where((t) => !_isInvestment(t.category))
        .toList();

    final spendingTotal = currentSpending.fold(0, (sum, t) => sum + t.amount);
    final investmentTotal = currentInvestment.fold(0, (sum, t) => sum + t.amount);
    final totalOutflow = spendingTotal + investmentTotal;
    final previousSpendingTotal = previousSpending.fold(0, (sum, t) => sum + t.amount);
    final spendingDelta = spendingTotal - previousSpendingTotal;

    // Category summaries (exclude investment)
    final topCategories = _buildTopCategories(currentSpending, spendingTotal);
    final remainingCategoryTotal = _computeRemainingCategoryTotal(currentSpending, topCategories);

    // Biggest increase/decrease
    final hasEnoughData = currentSpending.length >= 3;
    final biggestIncrease = _buildBiggestDelta(
      currentSpending, previousPeriodTxs
          .where((t) => !_isInvestment(t.category))
          .toList(),
      positive: true,
    );
    final biggestDecrease = _buildBiggestDelta(
      currentSpending, previousPeriodTxs
          .where((t) => !_isInvestment(t.category))
          .toList(),
      positive: false,
    );

    // Fixed expense summary
    final fixedExpenseSummary = _buildFixedExpenseSummary(
      currentMonthTxs,
      activeRecurringRules,
    );

    // Budget highlights (ADR-0025 §6: skip investment categories)
    final budgetHighlights = _buildBudgetHighlights(currentSpending, budgets);

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

  bool _isInvestment(String categoryName) {
    final cat = Category.predefined
        .where((c) => c.name == categoryName)
        .firstOrNull;
    return cat?.isInvestment ?? false;
  }

  List<MonthlyReviewCategorySummary> _buildTopCategories(
    List<Transaction> spendingTxs,
    int totalSpending,
  ) {
    // Group by category
    final categoryTotals = <String, int>{};
    for (final tx in spendingTxs) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    // Sort by amount descending, take top 5
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();

    return top5.map((entry) {
      final cat = Category.predefined
          .where((c) => c.name == entry.key)
          .firstOrNull;
      final emoji = cat?.emoji ?? '📌';
      final percent = totalSpending > 0
          ? ((entry.value / totalSpending) * 100).round()
          : 0;
      return MonthlyReviewCategorySummary(
        categoryName: entry.key,
        emoji: emoji,
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
    List<Transaction> previousSpending,
    {required bool positive}
  ) {
    // Group by category
    final currentTotals = <String, int>{};
    final previousTotals = <String, int>{};

    for (final tx in currentSpending) {
      currentTotals[tx.category] = (currentTotals[tx.category] ?? 0) + tx.amount;
    }
    for (final tx in previousSpending) {
      previousTotals[tx.category] = (previousTotals[tx.category] ?? 0) + tx.amount;
    }

    // Find all categories in either period
    final allCategories = {...currentTotals.keys, ...previousTotals.keys};

    // Compute deltas
    final deltas = <_DeltaEntry>[];
    for (final catName in allCategories) {
      final current = currentTotals[catName] ?? 0;
      final previous = previousTotals[catName] ?? 0;
      final deltaVnd = current - previous;
      final isNewlyIncurred = previous == 0 && current > 0;

      // Calculate percent (handle division by zero)
      double deltaPercent;
      if (previous == 0) {
        deltaPercent = 0; // will be flagged as newlyIncurred
      } else {
        deltaPercent = ((current - previous) / previous) * 100;
      }

      deltas.add(_DeltaEntry(
        categoryName: catName,
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

    final cat = Category.predefined
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
  ) {
    // Subscription category transactions
    final subscriptionTxs = currentMonthTxs
        .where((t) => t.category == 'Subscription')
        .toList();

    // Recurring-generated transactions (sourceRecurringId != null), exclude investment
    final recurringGeneratedTxs = currentMonthTxs
        .where((t) =>
            t.sourceRecurringId != null &&
            !_isInvestment(t.category))
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
          final cat = Category.predefined
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
  ) {
    // Group spending by category
    final categoryTotals = <String, int>{};
    for (final tx in currentSpending) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final budgetMap = {for (var b in budgets) b.categoryName: b};
    final highlights = <MonthlyReviewBudgetHighlight>[];

    // ADR-0025 §6: skip investment categories in budget highlights
    for (final category in Category.predefined) {
      if (category.isInvestment) continue;
      final budget = budgetMap[category.name];
      if (budget == null) continue;

      final spent = categoryTotals[category.name] ?? 0;
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
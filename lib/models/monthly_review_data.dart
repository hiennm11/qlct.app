import 'package:freezed_annotation/freezed_annotation.dart';

part 'monthly_review_data.freezed.dart';

/// Read-only derived analytics for a selected month.
/// Not persisted, not included in backup.
@freezed
class MonthlyReviewData with _$MonthlyReviewData {
  const factory MonthlyReviewData({
    required DateTime selectedMonth,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    required DateTime previousPeriodStart,
    required DateTime previousPeriodEnd,
    required int totalOutflow,
    required int spendingTotal,
    required int investmentTotal,
    required int previousSpendingTotal,
    required int spendingDelta,
    required List<MonthlyReviewCategorySummary> topCategories,
    required int remainingCategoryTotal,
    @Default(null) MonthlyReviewCategoryDelta? biggestIncrease,
    @Default(null) MonthlyReviewCategoryDelta? biggestDecrease,
    required MonthlyReviewFixedExpenseSummary fixedExpenseSummary,
    required List<MonthlyReviewBudgetHighlight> budgetHighlights,
    @Default(null) MonthlyReviewDaySummary? biggestSpendingDay,
    @Default(false) bool hasEnoughDataForDelta,
  }) = _MonthlyReviewData;
}

/// Category summary for monthly review
@freezed
class MonthlyReviewCategorySummary with _$MonthlyReviewCategorySummary {
  const factory MonthlyReviewCategorySummary({
    required String categoryName,
    required String emoji,
    required int amount,
    required int percentOfSpending,
  }) = _MonthlyReviewCategorySummary;
}

/// Category delta (increase/decrease) for monthly review
@freezed
class MonthlyReviewCategoryDelta with _$MonthlyReviewCategoryDelta {
  const factory MonthlyReviewCategoryDelta({
    required String categoryName,
    required String emoji,
    required int currentAmount,
    required int previousAmount,
    required int deltaVnd,
    required double deltaPercent,
    @Default(false) bool isNewlyIncurred,
  }) = _MonthlyReviewCategoryDelta;
}

/// Fixed expense summary for monthly review.
/// Union distinct of Subscription category + recurring-generated transactions,
/// excluding investment categories.
@freezed
class MonthlyReviewFixedExpenseSummary with _$MonthlyReviewFixedExpenseSummary {
  const factory MonthlyReviewFixedExpenseSummary({
    required int totalAmount,
    required int subscriptionAmount,
    required int recurringGeneratedAmount,
    required List<MonthlyReviewFixedExpenseItem> subscriptionItems,
    required List<MonthlyReviewFixedExpenseItem> recurringGeneratedItems,
    @Default([]) List<MonthlyReviewActiveRecurringRule> activeRecurringRules,
  }) = _MonthlyReviewFixedExpenseSummary;
}

/// Individual fixed expense item
@freezed
class MonthlyReviewFixedExpenseItem with _$MonthlyReviewFixedExpenseItem {
  const factory MonthlyReviewFixedExpenseItem({
    required String transactionId,
    required String categoryName,
    required String emoji,
    required int amount,
    required DateTime date,
    @Default('') String note,
    @Default(false) bool isRecurringGenerated,
  }) = _MonthlyReviewFixedExpenseItem;
}

/// Active recurring rule info shown for current month
@freezed
class MonthlyReviewActiveRecurringRule with _$MonthlyReviewActiveRecurringRule {
  const factory MonthlyReviewActiveRecurringRule({
    required String id,
    required String categoryName,
    required String emoji,
    required int amount,
    required String frequency,
  }) = _MonthlyReviewActiveRecurringRule;
}

/// Budget highlight for monthly review
@freezed
class MonthlyReviewBudgetHighlight with _$MonthlyReviewBudgetHighlight {
  const factory MonthlyReviewBudgetHighlight({
    required String categoryName,
    required String emoji,
    required int spent,
    required int limit,
    required int percentUsed,
    @Default(false) bool isExceeded,
    @Default(false) bool isWarning,
    // TODO(ADR-0032 §8): add carryAmount to show "Còn dư chuyển tháng sau"
    // Requires: add field here + update MonthlyReviewBuilder._buildBudgetHighlights
    // to pass snapshots with carryAmount + update MonthlyReviewViewModel to pass snapshots.
  }) = _MonthlyReviewBudgetHighlight;
}

/// Day spending summary for biggest spending day
@freezed
class MonthlyReviewDaySummary with _$MonthlyReviewDaySummary {
  const factory MonthlyReviewDaySummary({
    required DateTime date,
    required int totalAmount,
    required int transactionCount,
  }) = _MonthlyReviewDaySummary;
}
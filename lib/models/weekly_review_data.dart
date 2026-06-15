import 'package:freezed_annotation/freezed_annotation.dart';

part 'weekly_review_data.freezed.dart';

/// Read-only derived analytics for a calendar week (Mon-Sun).
/// Not persisted, not included in backup. Mirror MonthlyReviewData (ADR-0021).
///
/// ADR-0053: Weekly Review Card on Home (Epic 4)
@freezed
class WeeklyReviewData with _$WeeklyReviewData {
  const factory WeeklyReviewData({
    // Boundary
    required DateTime currentWeekStart,     // Mon 00:00 local
    required DateTime currentWeekEnd,       // Sun 23:59 local (or now if in progress)
    required DateTime previousCompareStart, // same-period previous week
    required DateTime previousCompareEnd,

    // Spending totals (exclude investment — mirror ADR-0021)
    required int weekSpent,
    required int prevWeekSpent,
    required int spendingDelta,             // weekSpent - prevWeekSpent

    // Top category delta (spending only, exclude investment)
    @Default(null) String? topCategoryId,
    @Default(0) int topCategoryDelta,       // absolute VND delta, primary metric
    @Default(0) int topCategoryCurrentSpent,
    @Default(0) int topCategoryPrevSpent,
    @Default(false) bool topCategoryNewlyIncurred,

    // Days with activity (spending only, exclude investment)
    @Default(0) int daysLogged,             // 0-7

    // Largest transaction (all categories incl. investment — grill Q4 deviation)
    @Default(null) WeeklyReviewLargestTransaction? largestTransaction,

    // Budget risk
    @Default([]) List<String> budgetRiskCategoryIds,

    // Upcoming recurring (next 7 days, all active rules)
    @Default(0) int upcomingRecurringCount,

    // Flags
    @Default(false) bool hasEnoughDataForDelta,
    @Default(WeeklyReviewLowDataState.empty) WeeklyReviewLowDataState lowDataState,
  }) = _WeeklyReviewData;
}

/// Largest transaction snapshot. Value type — does NOT hold full Transaction
/// (privacy: drop note, exact time). Date is day-only.
@freezed
class WeeklyReviewLargestTransaction with _$WeeklyReviewLargestTransaction {
  const factory WeeklyReviewLargestTransaction({
    required int amount,
    required String categoryId,
    required DateTime date, // date only (bỏ time)
  }) = _WeeklyReviewLargestTransaction;
}

/// Low-data state for the card. Drives UI: empty → empty state widget,
/// low → 1 insight chip, normal → 3 insight chips.
enum WeeklyReviewLowDataState {
  empty,   // 0 spending tx
  low,     // < 3 spending tx
  normal,  // >= 3 spending tx
}

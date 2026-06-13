import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_stats.freezed.dart';

/// Statistics for expense tracking.
///
/// [categoryTotals] is keyed by `Transaction.categoryId` (stable identity
/// per ADR-0027), NOT by the display-name snapshot. UI consumers must
/// resolve each id against the current `Category` catalog to obtain the
/// display name, emoji, and color (ADR-0036).
@freezed
class ExpenseStats with _$ExpenseStats {
  const factory ExpenseStats({
    required int todayExpense,
    required int weekExpense,
    required int monthExpense,
    required Map<String, int> categoryTotals,
  }) = _ExpenseStats;

  /// Create empty stats
  factory ExpenseStats.empty() => const ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 0,
        categoryTotals: {},
      );
}

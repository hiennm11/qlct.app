import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget_snapshot.freezed.dart';
part 'budget_snapshot.g.dart';

/// BudgetSnapshot: historical snapshot of monthly budget limits.
/// Created after month rollover to provide month-correct budget
/// context for past-month Monthly Review.
///
/// ADR-0025: Monthly Budget Snapshots
@freezed
class BudgetSnapshot with _$BudgetSnapshot {
  const factory BudgetSnapshot({
    required String yearMonth,
    required String categoryName,
    required int limitAmount,
    @Default(80) int alertThreshold,
    required DateTime createdAt,
  }) = _BudgetSnapshot;

  factory BudgetSnapshot.fromJson(Map<String, dynamic> json) =>
      _$BudgetSnapshotFromJson(json);
}

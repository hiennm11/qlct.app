import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget_plan.freezed.dart';
part 'budget_plan.g.dart';

/// BudgetPlan: planned budget for a future month.
/// One draft/applied plan per yearMonth.
///
/// ADR-0026: Monthly Budget Planning
@freezed
class BudgetPlan with _$BudgetPlan {
  const factory BudgetPlan({
    required String yearMonth,
    required int plannedTotalBudget,
    required String source,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(null) DateTime? appliedAt,
  }) = _BudgetPlan;

  factory BudgetPlan.fromJson(Map<String, dynamic> json) =>
      _$BudgetPlanFromJson(json);
}

/// BudgetPlanItem: per-category planned budget limit within a BudgetPlan.
/// Includes suggestion context and recommendation classification.
///
/// ADR-0026: Monthly Budget Planning
@freezed
class BudgetPlanItem with _$BudgetPlanItem {
  const factory BudgetPlanItem({
    required String yearMonth,
    required String categoryName,
    required int plannedLimit,
    @Default(80) int alertThreshold,
    @Default(0) int suggestedLimit,
    @Default(0) int baseLimit,
    @Default(0) int lastMonthSpent,
    @Default(false) bool wasOverBudgetLastMonth,
    @Default('keep') String recommendation,
  }) = _BudgetPlanItem;

  factory BudgetPlanItem.fromJson(Map<String, dynamic> json) =>
      _$BudgetPlanItemFromJson(json);
}

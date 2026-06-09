import 'package:freezed_annotation/freezed_annotation.dart';
import 'budget_plan.dart';

part 'monthly_budget_plan_data.freezed.dart';

/// Planning draft data output from MonthlyBudgetPlanBuilder.
/// Groups items by recommendation and exposes computed totals.
///
/// ADR-0026: Monthly Budget Planning
@freezed
class MonthlyBudgetPlanData with _$MonthlyBudgetPlanData {
  const factory MonthlyBudgetPlanData({
    required BudgetPlan plan,
    required List<BudgetPlanItem> items,
    required List<BudgetPlanItem> keepItems,
    required List<BudgetPlanItem> increaseItems,
    required List<BudgetPlanItem> decreaseItems,
    required int allocatedAmount,
    required int activeCategoryCount,
  }) = _MonthlyBudgetPlanData;
}

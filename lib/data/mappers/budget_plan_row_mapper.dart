import '../../models/budget_plan.dart';

/// Convert a [BudgetPlan] to a SQLite row map.
Map<String, dynamic> budgetPlanToRow(BudgetPlan plan) {
  return {
    'year_month': plan.yearMonth,
    'planned_total_budget': plan.plannedTotalBudget,
    'source': plan.source,
    'status': plan.status,
    'created_at': plan.createdAt.millisecondsSinceEpoch,
    'updated_at': plan.updatedAt.millisecondsSinceEpoch,
    'applied_at': plan.appliedAt?.millisecondsSinceEpoch,
  };
}

/// Convert a SQLite row map to a [BudgetPlan].
BudgetPlan budgetPlanFromRow(Map<String, dynamic> row) {
  final appliedAtMs = row['applied_at'] as int?;
  return BudgetPlan(
    yearMonth: row['year_month'] as String,
    plannedTotalBudget: row['planned_total_budget'] as int,
    source: row['source'] as String,
    status: row['status'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    appliedAt: appliedAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(appliedAtMs)
        : null,
  );
}

/// Convert a [BudgetPlanItem] to a SQLite row map.
Map<String, dynamic> budgetPlanItemToRow(BudgetPlanItem item) {
  return {
    'year_month': item.yearMonth,
    'category_name': item.categoryName,
    'planned_limit': item.plannedLimit,
    'alert_threshold': item.alertThreshold,
    'suggested_limit': item.suggestedLimit,
    'base_limit': item.baseLimit,
    'last_month_spent': item.lastMonthSpent,
    'was_over_budget_last_month': item.wasOverBudgetLastMonth ? 1 : 0,
    'recommendation': item.recommendation,
  };
}

/// Convert a SQLite row map to a [BudgetPlanItem].
BudgetPlanItem budgetPlanItemFromRow(Map<String, dynamic> row) {
  return BudgetPlanItem(
    yearMonth: row['year_month'] as String,
    categoryName: row['category_name'] as String,
    plannedLimit: row['planned_limit'] as int,
    alertThreshold: row['alert_threshold'] as int,
    suggestedLimit: row['suggested_limit'] as int,
    baseLimit: row['base_limit'] as int,
    lastMonthSpent: row['last_month_spent'] as int,
    wasOverBudgetLastMonth: (row['was_over_budget_last_month'] as int) == 1,
    recommendation: row['recommendation'] as String,
  );
}

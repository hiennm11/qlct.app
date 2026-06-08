import '../../models/budget.dart';
import '../../models/budget_snapshot.dart';

/// Convert a [BudgetSnapshot] to a SQLite row map.
Map<String, dynamic> budgetSnapshotToRow(BudgetSnapshot s) {
  return {
    'year_month': s.yearMonth,
    'category_name': s.categoryName,
    'limit_amount': s.limitAmount,
    'alert_threshold': s.alertThreshold,
    'created_at': s.createdAt.millisecondsSinceEpoch,
  };
}

/// Convert a SQLite row map to a [BudgetSnapshot].
BudgetSnapshot budgetSnapshotFromRow(Map<String, dynamic> row) {
  return BudgetSnapshot(
    yearMonth: row['year_month'] as String,
    categoryName: row['category_name'] as String,
    limitAmount: row['limit_amount'] as int,
    alertThreshold: row['alert_threshold'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}

/// ADR-0025 §5: Map a [BudgetSnapshot] to a [Budget] for MonthlyReviewBuilder.
/// The id is synthetic and includes yearMonth + categoryName to preserve
/// identity across the snapshot boundary.
Budget budgetSnapshotToBudget(BudgetSnapshot s) {
  return Budget(
    id: 'snapshot_${s.yearMonth}_${s.categoryName}',
    categoryName: s.categoryName,
    monthlyLimit: s.limitAmount,
    alertThreshold: s.alertThreshold,
    createdAt: s.createdAt,
  );
}
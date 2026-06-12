import '../../core/vietnamese_text_normalizer.dart';
import '../../models/budget.dart';
import '../../models/budget_snapshot.dart';

/// Convert a [BudgetSnapshot] to a SQLite row map.
Map<String, dynamic> budgetSnapshotToRow(BudgetSnapshot s) {
  return {
    'year_month': s.yearMonth,
    'category_name': s.categoryName,
    'category_id': s.categoryId,
    'limit_amount': s.limitAmount,
    'alert_threshold': s.alertThreshold,
    'created_at': s.createdAt.millisecondsSinceEpoch,
    'carry_amount': s.carryAmount,
  };
}

/// Convert a SQLite row map to a [BudgetSnapshot].
/// Tolerates rows missing category_id (e.g. old test fixtures) by deriving it.
/// Tolerates missing carry_amount (e.g. pre-v14 rows) defaulting to 0.
BudgetSnapshot budgetSnapshotFromRow(Map<String, dynamic> row) {
  final categoryId = row['category_id'] as String?;
  final carryAmount = row['carry_amount'] as int?;
  return BudgetSnapshot(
    yearMonth: row['year_month'] as String,
    categoryName: row['category_name'] as String,
    categoryId: categoryId ??
        'migrated_${normalizeVietnameseSearchText(row['category_name'] as String)}',
    limitAmount: row['limit_amount'] as int,
    alertThreshold: row['alert_threshold'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    carryAmount: carryAmount ?? 0,
  );
}

/// ADR-0025 §5: Map a [BudgetSnapshot] to a [Budget] for MonthlyReviewBuilder.
/// The id is synthetic and includes yearMonth + categoryId to preserve
/// identity across the snapshot boundary.
Budget budgetSnapshotToBudget(BudgetSnapshot s) {
  return Budget(
    id: 'snapshot_${s.yearMonth}_${s.categoryId}',
    categoryName: s.categoryName,
    categoryId: s.categoryId,
    monthlyLimit: s.limitAmount,
    alertThreshold: s.alertThreshold,
    createdAt: s.createdAt,
  );
}
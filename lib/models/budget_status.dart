import '../models/budget.dart';
import '../models/category.dart';

/// Alert level for budget status
enum AlertLevel { normal, warning, exceeded }

/// Total budget status combining total budget with current spending
class TotalBudgetStatus {
  final int limit;
  final int spent;
  final int remaining;
  final int percentUsed;
  final AlertLevel alertLevel;

  const TotalBudgetStatus({
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.percentUsed,
    required this.alertLevel,
  });

  /// Create TotalBudgetStatus from total budget and spent amount
  factory TotalBudgetStatus.fromTotalBudget(int limit, int spent) {
    final remaining = (limit - spent).clamp(0, limit);
    final percentUsed = limit > 0 ? ((spent / limit) * 100).round().clamp(0, 100) : 0;

    AlertLevel alertLevel;
    if (percentUsed >= 100) {
      alertLevel = AlertLevel.exceeded;
    } else if (percentUsed >= 80) {
      alertLevel = AlertLevel.warning;
    } else {
      alertLevel = AlertLevel.normal;
    }

    return TotalBudgetStatus(
      limit: limit,
      spent: spent,
      remaining: remaining,
      percentUsed: percentUsed,
      alertLevel: alertLevel,
    );
  }
}

/// Epoch constant for fallback Category constructors.
/// Budget status combining budget info with current spending
class BudgetStatus {
  final String categoryName;
  final String emoji;
  final int spent;
  final int limit;
  final int remaining;
  final int percentUsed;
  final AlertLevel alertLevel;

  const BudgetStatus({
    required this.categoryName,
    required this.emoji,
    required this.spent,
    required this.limit,
    required this.remaining,
    required this.percentUsed,
    required this.alertLevel,
  });

  /// Create BudgetStatus from Budget and spent amount
  factory BudgetStatus.fromBudget(Budget budget, int spent) {
    final limit = budget.monthlyLimit;
    final remaining = (limit - spent).clamp(0, limit);
    final percentUsed = limit > 0 ? ((spent / limit) * 100).round().clamp(0, 100) : 0;

    AlertLevel alertLevel;
    if (percentUsed >= 100) {
      alertLevel = AlertLevel.exceeded;
    } else if (percentUsed >= budget.alertThreshold) {
      alertLevel = AlertLevel.warning;
    } else {
      alertLevel = AlertLevel.normal;
    }

    // Find emoji from Category.predefined
    final category = Category.predefined.firstWhere(
      (c) => c.name == budget.categoryName,
      orElse: () => Category(
        id: '',
        name: '',
        normalizedName: '',
        emoji: '📌',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 0,
        quickAmountDefault: 0,
        quickAmountMax: 0,
        voicePhrases: [],
        sortOrder: 9999,
        isSystem: false,
        isArchived: false,
        createdAt: DateTime(1970),
        updatedAt: DateTime(1970),
      ),
    );

    return BudgetStatus(
      categoryName: budget.categoryName,
      emoji: category.emoji,
      spent: spent,
      limit: limit,
      remaining: remaining,
      percentUsed: percentUsed,
      alertLevel: alertLevel,
    );
  }

  /// Create BudgetStatus for category with spending but no budget
  factory BudgetStatus.noBudget(String categoryName, int spent) {
    final category = Category.predefined.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => Category(
        id: '',
        name: '',
        normalizedName: '',
        emoji: '📌',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 0,
        quickAmountDefault: 0,
        quickAmountMax: 0,
        voicePhrases: [],
        sortOrder: 9999,
        isSystem: false,
        isArchived: false,
        createdAt: DateTime(1970),
        updatedAt: DateTime(1970),
      ),
    );

    return BudgetStatus(
      categoryName: categoryName,
      emoji: category.emoji,
      spent: spent,
      limit: 0,
      remaining: 0,
      percentUsed: 0,
      alertLevel: AlertLevel.normal,
    );
  }
}
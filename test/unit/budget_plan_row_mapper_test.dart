import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/budget_plan_row_mapper.dart';
import 'package:qlct/models/budget_plan.dart';

void main() {
  group('budgetPlanToRow', () {
    test('maps all fields to SQLite row shape', () {
      final created = DateTime(2026, 6, 8, 10, 0);
      final updated = DateTime(2026, 6, 8, 11, 0);
      final applied = DateTime(2026, 7, 1, 0, 0);
      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'previousMonth',
        status: 'applied',
        createdAt: created,
        updatedAt: updated,
        appliedAt: applied,
      );

      final row = budgetPlanToRow(plan);

      expect(row['year_month'], '2026-07');
      expect(row['planned_total_budget'], 15000000);
      expect(row['source'], 'previousMonth');
      expect(row['status'], 'applied');
      expect(row['created_at'], created.millisecondsSinceEpoch);
      expect(row['updated_at'], updated.millisecondsSinceEpoch);
      expect(row['applied_at'], applied.millisecondsSinceEpoch);
    });

    test('appliedAt null maps to null applied_at', () {
      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'empty',
        status: 'draft',
        createdAt: DateTime.utc(2026, 6, 8, 10),
        updatedAt: DateTime.utc(2026, 6, 8, 10),
      );

      final row = budgetPlanToRow(plan);
      expect(row['applied_at'], isNull);
    });
  });

  group('budgetPlanFromRow', () {
    test('parses all fields from SQLite row shape', () {
      final now = DateTime.now();
      final row = {
        'year_month': '2026-07',
        'planned_total_budget': 15000000,
        'source': 'previousMonth',
        'status': 'draft',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'applied_at': null,
      };

      final plan = budgetPlanFromRow(row);

      expect(plan.yearMonth, '2026-07');
      expect(plan.plannedTotalBudget, 15000000);
      expect(plan.source, 'previousMonth');
      expect(plan.status, 'draft');
      expect(plan.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(plan.updatedAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(plan.appliedAt, isNull);
    });

    test('parses non-null applied_at', () {
      final applied = DateTime.now();
      final row = {
        'year_month': '2026-07',
        'planned_total_budget': 15000000,
        'source': 'currentBudget',
        'status': 'applied',
        'created_at': applied.millisecondsSinceEpoch,
        'updated_at': applied.millisecondsSinceEpoch,
        'applied_at': applied.millisecondsSinceEpoch,
      };

      final plan = budgetPlanFromRow(row);
      expect(plan.appliedAt!.millisecondsSinceEpoch, applied.millisecondsSinceEpoch);
      expect(plan.status, 'applied');
    });
  });

  group('budgetPlanToRow + budgetPlanFromRow roundtrip', () {
    test('preserves all data with appliedAt set', () {
      final created = DateTime(2026, 7, 15, 9);
      final updated = DateTime(2026, 8, 1, 0);
      final applied = DateTime(2026, 8, 1, 0);
      final original = BudgetPlan(
        yearMonth: '2026-08',
        plannedTotalBudget: 20000000,
        source: 'currentBudget',
        status: 'applied',
        createdAt: created,
        updatedAt: updated,
        appliedAt: applied,
      );

      final row = budgetPlanToRow(original);
      final restored = budgetPlanFromRow(row);

      expect(restored.yearMonth, original.yearMonth);
      expect(restored.plannedTotalBudget, original.plannedTotalBudget);
      expect(restored.source, original.source);
      expect(restored.status, original.status);
      expect(restored.createdAt.millisecondsSinceEpoch, original.createdAt.millisecondsSinceEpoch);
      expect(restored.updatedAt.millisecondsSinceEpoch, original.updatedAt.millisecondsSinceEpoch);
      expect(restored.appliedAt!.millisecondsSinceEpoch, original.appliedAt!.millisecondsSinceEpoch);
    });

    test('preserves all data with appliedAt null', () {
      final original = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 10000000,
        source: 'empty',
        status: 'draft',
        createdAt: DateTime(2026, 6, 8, 10),
        updatedAt: DateTime(2026, 6, 8, 10),
      );

      final row = budgetPlanToRow(original);
      final restored = budgetPlanFromRow(row);

      expect(restored.yearMonth, original.yearMonth);
      expect(restored.plannedTotalBudget, original.plannedTotalBudget);
      expect(restored.source, original.source);
      expect(restored.status, original.status);
      expect(restored.appliedAt, isNull);
    });
  });

  group('budgetPlanItemToRow', () {
    test('maps all fields to SQLite row shape with bool -> 0/1', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Ăn ngoài',
        plannedLimit: 3000000,
        alertThreshold: 80,
        suggestedLimit: 3500000,
        baseLimit: 3000000,
        lastMonthSpent: 3500000,
        wasOverBudgetLastMonth: true,
        recommendation: 'increase',
      );

      final row = budgetPlanItemToRow(item);

      expect(row['year_month'], '2026-07');
      expect(row['category_name'], 'Ăn ngoài');
      expect(row['planned_limit'], 3000000);
      expect(row['alert_threshold'], 80);
      expect(row['suggested_limit'], 3500000);
      expect(row['base_limit'], 3000000);
      expect(row['last_month_spent'], 3500000);
      expect(row['was_over_budget_last_month'], 1);
      expect(row['recommendation'], 'increase');
    });

    test('wasOverBudgetLastMonth false maps to 0', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Cà phê',
        plannedLimit: 1000000,
        wasOverBudgetLastMonth: false,
        recommendation: 'keep',
      );

      final row = budgetPlanItemToRow(item);
      expect(row['was_over_budget_last_month'], 0);
    });
  });

  group('budgetPlanItemFromRow', () {
    test('parses all fields from SQLite row shape with 0/1 -> bool', () {
      final row = {
        'year_month': '2026-07',
        'category_name': 'Ăn ngoài',
        'planned_limit': 3000000,
        'alert_threshold': 80,
        'suggested_limit': 3500000,
        'base_limit': 3000000,
        'last_month_spent': 3500000,
        'was_over_budget_last_month': 1,
        'recommendation': 'increase',
      };

      final item = budgetPlanItemFromRow(row);

      expect(item.yearMonth, '2026-07');
      expect(item.categoryName, 'Ăn ngoài');
      expect(item.plannedLimit, 3000000);
      expect(item.alertThreshold, 80);
      expect(item.suggestedLimit, 3500000);
      expect(item.baseLimit, 3000000);
      expect(item.lastMonthSpent, 3500000);
      expect(item.wasOverBudgetLastMonth, isTrue);
      expect(item.recommendation, 'increase');
    });

    test('was_over_budget_last_month 0 parses to false', () {
      final row = {
        'year_month': '2026-07',
        'category_name': 'Cà phê',
        'planned_limit': 1000000,
        'alert_threshold': 80,
        'suggested_limit': 0,
        'base_limit': 0,
        'last_month_spent': 0,
        'was_over_budget_last_month': 0,
        'recommendation': 'keep',
      };

      final item = budgetPlanItemFromRow(row);
      expect(item.wasOverBudgetLastMonth, isFalse);
    });
  });

  group('budgetPlanItemToRow + budgetPlanItemFromRow roundtrip', () {
    test('preserves all data', () {
      final original = BudgetPlanItem(
        yearMonth: '2026-08',
        categoryName: 'Subscription',
        plannedLimit: 500000,
        alertThreshold: 75,
        suggestedLimit: 600000,
        baseLimit: 500000,
        lastMonthSpent: 600000,
        wasOverBudgetLastMonth: true,
        recommendation: 'decrease',
      );

      final row = budgetPlanItemToRow(original);
      final restored = budgetPlanItemFromRow(row);

      expect(restored.yearMonth, original.yearMonth);
      expect(restored.categoryName, original.categoryName);
      expect(restored.plannedLimit, original.plannedLimit);
      expect(restored.alertThreshold, original.alertThreshold);
      expect(restored.suggestedLimit, original.suggestedLimit);
      expect(restored.baseLimit, original.baseLimit);
      expect(restored.lastMonthSpent, original.lastMonthSpent);
      expect(restored.wasOverBudgetLastMonth, original.wasOverBudgetLastMonth);
      expect(restored.recommendation, original.recommendation);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/budget_plan.dart';

void main() {
  group('BudgetPlan model', () {
    test('creates with all required fields', () {
      final now = DateTime(2026, 6, 8, 10, 30);
      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'previousMonth',
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );

      expect(plan.yearMonth, '2026-07');
      expect(plan.plannedTotalBudget, 15000000);
      expect(plan.source, 'previousMonth');
      expect(plan.status, 'draft');
      expect(plan.createdAt, now);
      expect(plan.updatedAt, now);
      expect(plan.appliedAt, isNull);
    });

    test('appliedAt is optional', () {
      final now = DateTime(2026, 7, 1, 0, 0);
      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'currentBudget',
        status: 'applied',
        createdAt: now,
        updatedAt: now,
        appliedAt: now,
      );

      expect(plan.appliedAt, isNotNull);
      expect(plan.appliedAt, now);
    });

    test('JSON roundtrip preserves all fields including nullable appliedAt', () {
      final created = DateTime.utc(2026, 6, 8, 10, 30);
      final updated = DateTime.utc(2026, 6, 8, 11, 0);
      final applied = DateTime.utc(2026, 7, 1, 0, 0);

      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'previousMonth',
        status: 'applied',
        createdAt: created,
        updatedAt: updated,
        appliedAt: applied,
      );

      final json = plan.toJson();
      final restored = BudgetPlan.fromJson(json);

      expect(restored.yearMonth, '2026-07');
      expect(restored.plannedTotalBudget, 15000000);
      expect(restored.source, 'previousMonth');
      expect(restored.status, 'applied');
      expect(restored.createdAt, created);
      expect(restored.updatedAt, updated);
      expect(restored.appliedAt, applied);
    });

    test('JSON roundtrip with null appliedAt', () {
      final created = DateTime.utc(2026, 6, 8, 10, 30);
      final updated = DateTime.utc(2026, 6, 8, 11, 0);

      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'empty',
        status: 'draft',
        createdAt: created,
        updatedAt: updated,
      );

      final json = plan.toJson();
      expect(json['appliedAt'], isNull);

      final restored = BudgetPlan.fromJson(json);
      expect(restored.appliedAt, isNull);
      expect(restored.status, 'draft');
    });

    test('fromJson handles all required fields', () {
      final json = {
        'yearMonth': '2026-08',
        'plannedTotalBudget': 20000000,
        'source': 'currentBudget',
        'status': 'draft',
        'createdAt': '2026-06-08T10:30:00.000',
        'updatedAt': '2026-06-08T10:30:00.000',
      };

      final plan = BudgetPlan.fromJson(json);

      expect(plan.yearMonth, '2026-08');
      expect(plan.plannedTotalBudget, 20000000);
      expect(plan.source, 'currentBudget');
      expect(plan.status, 'draft');
      expect(plan.appliedAt, isNull);
    });

    test('toJson output contains all fields', () {
      final now = DateTime.utc(2026, 6, 8, 10, 0);
      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'previousMonth',
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );

      final json = plan.toJson();
      expect(json['yearMonth'], '2026-07');
      expect(json['plannedTotalBudget'], 15000000);
      expect(json['source'], 'previousMonth');
      expect(json['status'], 'draft');
      expect(json['createdAt'], isA<String>());
      expect(json['updatedAt'], isA<String>());
      expect(json['appliedAt'], isNull);
    });
  });

  group('BudgetPlanItem model', () {
    test('creates with all required fields and defaults', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Ăn ngoài',
        plannedLimit: 3000000,
      );

      expect(item.yearMonth, '2026-07');
      expect(item.categoryName, 'Ăn ngoài');
      expect(item.plannedLimit, 3000000);
      expect(item.alertThreshold, 80);
      expect(item.suggestedLimit, 0);
      expect(item.baseLimit, 0);
      expect(item.lastMonthSpent, 0);
      expect(item.wasOverBudgetLastMonth, isFalse);
      expect(item.recommendation, 'keep');
    });

    test('creates with all fields specified', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Ăn ngoài',
        plannedLimit: 3000000,
        alertThreshold: 75,
        suggestedLimit: 3500000,
        baseLimit: 3000000,
        lastMonthSpent: 3500000,
        wasOverBudgetLastMonth: true,
        recommendation: 'increase',
      );

      expect(item.alertThreshold, 75);
      expect(item.suggestedLimit, 3500000);
      expect(item.baseLimit, 3000000);
      expect(item.lastMonthSpent, 3500000);
      expect(item.wasOverBudgetLastMonth, isTrue);
      expect(item.recommendation, 'increase');
    });

    test('JSON roundtrip preserves all fields', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Cà phê',
        plannedLimit: 1000000,
        alertThreshold: 70,
        suggestedLimit: 1200000,
        baseLimit: 1000000,
        lastMonthSpent: 1200000,
        wasOverBudgetLastMonth: true,
        recommendation: 'increase',
      );

      final json = item.toJson();
      final restored = BudgetPlanItem.fromJson(json);

      expect(restored.yearMonth, '2026-07');
      expect(restored.categoryName, 'Cà phê');
      expect(restored.plannedLimit, 1000000);
      expect(restored.alertThreshold, 70);
      expect(restored.suggestedLimit, 1200000);
      expect(restored.baseLimit, 1000000);
      expect(restored.lastMonthSpent, 1200000);
      expect(restored.wasOverBudgetLastMonth, isTrue);
      expect(restored.recommendation, 'increase');
    });

    test('JSON fromJson applies defaults for missing optional fields', () {
      final json = {
        'yearMonth': '2026-07',
        'categoryName': 'Mua online',
        'plannedLimit': 2000000,
      };

      final item = BudgetPlanItem.fromJson(json);

      expect(item.alertThreshold, 80);
      expect(item.suggestedLimit, 0);
      expect(item.baseLimit, 0);
      expect(item.lastMonthSpent, 0);
      expect(item.wasOverBudgetLastMonth, isFalse);
      expect(item.recommendation, 'keep');
    });

    test('copyWith updates selected fields and keeps others', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Ăn ngoài',
        plannedLimit: 3000000,
        recommendation: 'keep',
      );

      final updated = item.copyWith(
        plannedLimit: 3500000,
        recommendation: 'increase',
      );

      expect(updated.yearMonth, '2026-07');
      expect(updated.categoryName, 'Ăn ngoài');
      expect(updated.plannedLimit, 3500000);
      expect(updated.recommendation, 'increase');
    });
  });
}

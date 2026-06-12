// ADR-0029: categoryId round-trip tests for representative models.
// Tests: Transaction (single-id), BudgetPlanItem (composite-key model).
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/transaction_row_mapper.dart';
import 'package:qlct/data/mappers/budget_row_mapper.dart';
import 'package:qlct/data/mappers/budget_snapshot_row_mapper.dart';
import 'package:qlct/data/mappers/budget_plan_row_mapper.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/budget_plan.dart';

void main() {
  group('transactionToRow / transactionFromRow', () {
    test('categoryId round-trips through toRow and fromRow', () {
      final t = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍜',
        date: DateTime(2026, 6, 7, 10, 30),
        note: 'lunch',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);
      expect(row['category_id'], 'food_out');

      final restored = transactionFromRow(row);
      expect(restored.categoryId, 'food_out');
      expect(restored.category, 'Ăn ngoài');
    });

    test('transaction round-trip preserves all fields including categoryId', () {
      final original = Transaction(
        id: 'tx-2',
        amount: 100000,
        category: 'Cà phê',
        categoryId: 'coffee',
        emoji: '☕',
        date: DateTime(2026, 6, 8),
        note: 'sáng',
        sourceRecurringId: 'rec-1',
      );
      final row = transactionToRow(original);
      final restored = transactionFromRow(row);

      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.category, original.category);
      expect(restored.categoryId, original.categoryId);
      expect(restored.emoji, original.emoji);
      expect(restored.date, original.date);
      expect(restored.note, original.note);
      expect(restored.sourceRecurringId, original.sourceRecurringId);
    });
  });

  group('budgetSnapshotToRow / budgetSnapshotFromRow', () {
    test('categoryId round-trips for composite-key BudgetSnapshot', () {
      final s = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );
      final row = budgetSnapshotToRow(s);
      expect(row['category_id'], 'food_out');
      expect(row['year_month'], '2026-05');
      expect(row['category_name'], 'Ăn ngoài');

      final restored = budgetSnapshotFromRow(row);
      expect(restored.categoryId, 'food_out');
      expect(restored.categoryName, 'Ăn ngoài');
      expect(restored.yearMonth, '2026-05');
    });

    test('BudgetSnapshot round-trip preserves all fields', () {
      final original = BudgetSnapshot(
        yearMonth: '2026-06',
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        limitAmount: 1000000,
        alertThreshold: 85,
        createdAt: DateTime(2026, 7, 1),
      );
      final row = budgetSnapshotToRow(original);
      final restored = budgetSnapshotFromRow(row);

      expect(restored.yearMonth, original.yearMonth);
      expect(restored.categoryName, original.categoryName);
      expect(restored.categoryId, original.categoryId);
      expect(restored.limitAmount, original.limitAmount);
      expect(restored.alertThreshold, original.alertThreshold);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('budgetPlanItemToRow / budgetPlanItemFromRow', () {
    test('categoryId round-trips for composite-key BudgetPlanItem', () {
      final item = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        plannedLimit: 3500000,
        alertThreshold: 80,
        suggestedLimit: 3500000,
        baseLimit: 3000000,
        lastMonthSpent: 3200000,
        wasOverBudgetLastMonth: true,
        recommendation: 'increase',
      );
      final row = budgetPlanItemToRow(item);
      expect(row['category_id'], 'food_out');

      final restored = budgetPlanItemFromRow(row);
      expect(restored.categoryId, 'food_out');
      expect(restored.categoryName, 'Ăn ngoài');
      expect(restored.yearMonth, '2026-07');
    });

    test('BudgetPlanItem round-trip preserves all fields', () {
      final original = BudgetPlanItem(
        yearMonth: '2026-08',
        categoryName: 'Mua online',
        categoryId: 'online_shopping',
        plannedLimit: 500000,
        alertThreshold: 80,
        suggestedLimit: 450000,
        baseLimit: 400000,
        lastMonthSpent: 380000,
        wasOverBudgetLastMonth: false,
        recommendation: 'keep',
      );
      final row = budgetPlanItemToRow(original);
      final restored = budgetPlanItemFromRow(row);

      expect(restored.yearMonth, original.yearMonth);
      expect(restored.categoryName, original.categoryName);
      expect(restored.categoryId, original.categoryId);
      expect(restored.plannedLimit, original.plannedLimit);
      expect(restored.alertThreshold, original.alertThreshold);
      expect(restored.suggestedLimit, original.suggestedLimit);
      expect(restored.baseLimit, original.baseLimit);
      expect(restored.lastMonthSpent, original.lastMonthSpent);
      expect(restored.wasOverBudgetLastMonth, original.wasOverBudgetLastMonth);
      expect(restored.recommendation, original.recommendation);
    });
  });

  group('budgetToRow / budgetFromRow', () {
    test('categoryId round-trips for Budget', () {
      final b = Budget(
        id: 'b-1',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        monthlyLimit: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 1, 1),
      );
      final row = budgetToRow(b);
      expect(row['category_id'], 'food_out');

      final restored = budgetFromRow(row);
      expect(restored.categoryId, 'food_out');
      expect(restored.categoryName, 'Ăn ngoài');
    });
  });

  group('budgetSnapshotToBudget (synthetic Budget from Snapshot)', () {
    test('uses categoryId in synthetic id, preserves categoryId field', () {
      final s = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );
      final budget = budgetSnapshotToBudget(s);

      expect(budget.id, contains('food_out'),
          reason: 'synthetic Budget id should include categoryId');
      expect(budget.categoryId, 'food_out');
      expect(budget.categoryName, 'Ăn ngoài');
    });
  });
}

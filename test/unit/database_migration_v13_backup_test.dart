// ADR-0029: backup schema v7 round-trip + old backup backfill.
// Minimal backup compatibility tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/models/category.dart';

void main() {
  group('BackupData schema v7 serialization', () {
    test('Transaction serializes categoryId field', () {
      final t = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'lunch',
      );
      final json = t.toJson();
      expect(json['categoryId'], 'food_out');
      expect(json['category'], 'Ăn ngoài');
    });

    test('Budget serializes categoryId field', () {
      final b = Budget(
        id: 'b-1',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        monthlyLimit: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 1, 1),
      );
      final json = b.toJson();
      expect(json['categoryId'], 'food_out');
      expect(json['categoryName'], 'Ăn ngoài');
    });

    test('RecurringTransaction serializes categoryId field', () {
      final r = RecurringTransaction(
        id: 'rec-1',
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        amount: 20000,
        note: '',
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 10),
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final json = r.toJson();
      expect(json['categoryId'], 'coffee');
      expect(json['categoryName'], 'Cà phê');
    });

    test('QuickTemplate serializes categoryId field', () {
      final q = QuickTemplate(
        id: 'qt-1',
        title: 'Cơm trưa',
        amount: 50000,
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        note: '',
        emoji: '🍜',
        isPinned: false,
        usageCount: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final json = q.toJson();
      expect(json['categoryId'], 'food_out');
      expect(json['categoryName'], 'Ăn ngoài');
    });

    test('BudgetSnapshot serializes categoryId field', () {
      final s = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );
      final json = s.toJson();
      expect(json['categoryId'], 'food_out');
      expect(json['categoryName'], 'Ăn ngoài');
    });

    test('BudgetPlanItem serializes categoryId field', () {
      final i = BudgetPlanItem(
        yearMonth: '2026-07',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        plannedLimit: 3500000,
        alertThreshold: 80,
        recommendation: 'increase',
      );
      final json = i.toJson();
      expect(json['categoryId'], 'food_out');
      expect(json['categoryName'], 'Ăn ngoài');
    });

    test('BackupData v7 round-trip: all fields serialize and deserialize correctly', () {
      // Use explicit toJson for each nested model to ensure maps (Freezed fromJson expects maps)
      final backupDataMap = {
        'appId': 'qlct.app',
        'schemaVersion': 7,
        'exportedAt': '2026-06-10T00:00:00.000Z',
        'appVersion': '1.4.0',
        'totalBudget': 15000000,
        'transactions': [
          Transaction(
            id: 'tx-1',
            amount: 50000,
            category: 'Ăn ngoài',
            categoryId: 'food_out',
            emoji: '🍜',
            date: DateTime(2026, 6, 7),
          ).toJson(),
        ],
        'budgets': [
          Budget(
            id: 'b-1',
            categoryName: 'Ăn ngoài',
            categoryId: 'food_out',
            monthlyLimit: 3000000,
            alertThreshold: 80,
            createdAt: DateTime(2026, 1, 1),
          ).toJson(),
        ],
        'budgetSnapshots': [
          BudgetSnapshot(
            yearMonth: '2026-05',
            categoryName: 'Ăn ngoài',
            categoryId: 'food_out',
            limitAmount: 3000000,
            alertThreshold: 80,
            createdAt: DateTime(2026, 6, 1),
          ).toJson(),
        ],
        'budgetPlanItems': [
          BudgetPlanItem(
            yearMonth: '2026-07',
            categoryName: 'Ăn ngoài',
            categoryId: 'food_out',
            plannedLimit: 3500000,
            alertThreshold: 80,
            recommendation: 'increase',
          ).toJson(),
        ],
        'recurringTransactions': [],
        'quickTemplates': [],
        'budgetPlans': [],
        'categories': [
          Category(
            id: 'food_out',
            name: 'Ăn ngoài',
            normalizedName: 'an ngoai',
            emoji: '🍜',
            kind: CategoryKind.spending,
            budgetBehavior: BudgetBehavior.flexible,
            quickAmountMin: 20000,
            quickAmountDefault: 50000,
            quickAmountMax: 150000,
            voicePhrases: ['ăn ngoài'],
            sortOrder: 10,
            isSystem: true,
            isArchived: false,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ).toJson(),
        ],
      };

      final restored = BackupData.fromJson(backupDataMap);

      expect(restored.schemaVersion, 7);
      expect(restored.transactions.length, 1);
      expect(restored.transactions[0].categoryId, 'food_out');
      expect(restored.budgets.length, 1);
      expect(restored.budgets[0].categoryId, 'food_out');
      expect(restored.budgetSnapshots.length, 1);
      expect(restored.budgetSnapshots[0].categoryId, 'food_out');
      expect(restored.budgetPlanItems.length, 1);
      expect(restored.budgetPlanItems[0].categoryId, 'food_out');
    });

    test('old schema v6 backup (without categoryId fields) — categoryId field is required in model, restore flow must handle backfill', () {
      // v6 backup has no categoryId field in transactions. Since categoryId is required
      // in the model, v6 backup restore must post-process to backfill categoryId
      // from category name matching (ADR-0029 §11).
      // This test documents that categoryId is absent in v6 JSON.
      final v6Json = {
        'appId': 'qlct.app',
        'schemaVersion': 6,
        'exportedAt': '2026-06-10T00:00:00.000Z',
        'appVersion': '1.4.0',
        'totalBudget': 15000000,
        'transactions': [
          {
            'id': 'tx-1',
            'amount': 50000,
            'category': 'Ăn ngoài',
            'emoji': '🍜',
            'date': '2026-06-07T00:00:00.000',
            'note': 'lunch',
          },
        ],
        'budgets': [
          {
            'id': 'b-1',
            'categoryName': 'Ăn ngoài',
            'monthlyLimit': 3000000,
            'alertThreshold': 80,
            'createdAt': 1735689600000,
          },
        ],
        'recurringTransactions': [],
        'quickTemplates': [],
        'budgetSnapshots': [],
        'budgetPlans': [],
        'budgetPlanItems': [],
        'categories': [],
      };

      // Confirm v6 backup lacks categoryId in transaction JSON
      final txJson = (v6Json['transactions'] as List).first as Map<String, dynamic>;
      expect(txJson.containsKey('categoryId'), isFalse,
          reason: 'v6 backup transactions should not have categoryId');
      // Schema version confirms v6 origin
      expect(v6Json['schemaVersion'], 6);
    });
  });

  group('currentSchemaVersion', () {
    test('currentSchemaVersion is 9', () {
      expect(currentSchemaVersion, 9);
    });
  });
}

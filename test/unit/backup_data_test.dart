import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/models/category.dart';

void main() {
  group('BackupData', () {
    final sampleTx = Transaction(
      id: 'tx-1',
      amount: 50000,
      category: 'Cà phê',
      categoryId: 'coffee',
      emoji: '☕',
      date: DateTime(2026, 6, 1, 8, 0),
      note: 'Test note',
    );

    final sampleBudget = Budget(
      id: 'b-1',
      categoryName: 'Ăn ngoài',
      categoryId: 'food_out',
      monthlyLimit: 3000000,
      alertThreshold: 80,
      createdAt: DateTime(2026, 1, 1),
    );

    final sampleRecurring = RecurringTransaction(
      id: 'r-1',
      categoryName: 'Subscription',
      categoryId: 'subscription',
      amount: 200000,
      note: 'GitHub',
      frequency: 'monthly',
      nextRunAt: DateTime(2026, 7, 1),
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

    final sampleTemplate = QuickTemplate(
      id: 'q-1',
      title: 'Cơm trưa',
      amount: 35000,
      categoryName: 'Ăn ngoài',
      categoryId: 'food_out',
      emoji: '🍜',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

    test('can construct with full data and access all fields', () {
      final backup = BackupData(
        schemaVersion: 2,
        exportedAt: '2026-06-05T10:00:00.000Z',
        appVersion: '1.0.0',
        totalBudget: 15000000,
        transactions: [sampleTx],
        budgets: [sampleBudget],
        recurringTransactions: [sampleRecurring],
        quickTemplates: [sampleTemplate],
      );

      expect(backup.schemaVersion, 2);
      expect(backup.exportedAt, '2026-06-05T10:00:00.000Z');
      expect(backup.appVersion, '1.0.0');
      expect(backup.totalBudget, 15000000);
      expect(backup.transactions.length, 1);
      expect(backup.transactions.first.id, 'tx-1');
      expect(backup.transactions.first.amount, 50000);
      expect(backup.transactions.first.category, 'Cà phê');
      expect(backup.budgets.length, 1);
      expect(backup.budgets.first.categoryName, 'Ăn ngoài');
      expect(backup.budgets.first.monthlyLimit, 3000000);
      expect(backup.recurringTransactions.length, 1);
      expect(backup.recurringTransactions.first.frequency, 'monthly');
      expect(backup.recurringTransactions.first.isActive, isTrue);
      expect(backup.quickTemplates.length, 1);
      expect(backup.quickTemplates.first.id, 'q-1');
      expect(backup.quickTemplates.first.title, 'Cơm trưa');
    });

    test('defaults for empty data', () {
      final backup = BackupData(
        schemaVersion: 2,
        exportedAt: '2026-06-05T10:00:00.000Z',
        appVersion: '1.0.0',
      );

      expect(backup.totalBudget, 0);
      expect(backup.transactions, isEmpty);
      expect(backup.budgets, isEmpty);
      expect(backup.recurringTransactions, isEmpty);
      expect(backup.quickTemplates, isEmpty);
    });

    test('multiple transactions preserve order', () {
      final txs = List.generate(5, (i) => Transaction(
        id: 'tx-$i',
        amount: (i + 1) * 10000,
        category: 'Cà phê',
        categoryId: 'coffee',
        emoji: '☕',
        date: DateTime(2026, 6, i + 1),
      ));

      final backup = BackupData(
        schemaVersion: 2,
        exportedAt: '2026-06-05T10:00:00.000Z',
        appVersion: '1.0.0',
        transactions: txs,
      );

      expect(backup.transactions.length, 5);
      expect(backup.transactions[0].id, 'tx-0');
      expect(backup.transactions[4].id, 'tx-4');
    });

    test('currentSchemaVersion is 9 (ADR-0037)', () {
      expect(currentSchemaVersion, 9);
    });

    test('appId field present in model with default', () {
      // v1/v2 JSON missing appId should parse with null/empty default
      final v2Json = {
        'schemaVersion': 2,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        // no appId field — v1/v2 compatibility
      };

      final backup = BackupData.fromJson(v2Json);

      expect(backup.schemaVersion, 2);
      expect(backup.appId, isEmpty);
    });

    test('v3 JSON with appId parses correctly', () {
      final v3Json = {
        'appId': 'qlct.app',
        'schemaVersion': 3,
        'exportedAt': '2026-06-07T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 20000000,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
      };

      final backup = BackupData.fromJson(v3Json);

      expect(backup.appId, 'qlct.app');
      expect(backup.schemaVersion, 3);
      expect(backup.totalBudget, 20000000);
    });

    test('toJson includes appId when set', () {
      final backup = BackupData(
        appId: 'qlct.app',
        schemaVersion: 3,
        exportedAt: '2026-06-07T10:00:00.000Z',
        appVersion: '1.0.0',
        totalBudget: 15000000,
      );

      final json = backup.toJson();

      expect(json['appId'], 'qlct.app');
      expect(json['schemaVersion'], 3);
    });

    test('v1 JSON without appId round-trips with empty appId default', () {
      final v1Json = {
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
      };

      final backup = BackupData.fromJson(v1Json);

      // Default for appId on a v1 file is empty string (validation gates
      // v3+ separately via raw JSON check, not via the parsed model).
      expect(backup.appId, '');
      expect(backup.schemaVersion, 1);
    });

    test('handles mixed data: some default, some provided', () {
      final backup = BackupData(
        schemaVersion: 2,
        exportedAt: '2026-06-05T10:00:00.000Z',
        appVersion: '1.0.0',
        transactions: [sampleTx],
        budgets: [],
      );

      expect(backup.transactions.length, 1);
      expect(backup.budgets, isEmpty);
      expect(backup.recurringTransactions, isEmpty);
      expect(backup.quickTemplates, isEmpty);
      expect(backup.totalBudget, 0);
    });

    test('v1 JSON parses with missing quickTemplates (defaults to [])', () {
      // Simulate v1 JSON: no quickTemplates field
      final v1Json = {
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        // no 'quickTemplates' field
      };

      final backup = BackupData.fromJson(v1Json);

      expect(backup.schemaVersion, 1);
      expect(backup.quickTemplates, isEmpty);
    });

    test('v3 JSON parses with missing budgetSnapshots (defaults to [])',
        () {
      // Simulate v3 JSON: no budgetSnapshots field
      final v3Json = {
        'appId': 'qlct.app',
        'schemaVersion': 3,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        // no 'budgetSnapshots' field
      };

      final backup = BackupData.fromJson(v3Json);

      expect(backup.schemaVersion, 3);
      expect(backup.budgetSnapshots, isEmpty);
    });

    // ADR-0026: v5 schema — budgetPlans and budgetPlanItems present
    test('v5 JSON with budgetPlans and budgetPlanItems parses correctly', () {
      final v5Json = {
        'appId': 'qlct.app',
        'schemaVersion': 5,
        'exportedAt': '2026-06-09T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 20000000,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        'budgetSnapshots': <Map<String, dynamic>>[],
        'budgetPlans': [
          {
            'yearMonth': '2026-07',
            'plannedTotalBudget': 15000000,
            'source': 'previous_snapshot',
            'status': 'draft',
            'createdAt': '2026-06-09T00:00:00.000Z',
            'updatedAt': '2026-06-09T00:00:00.000Z',
          }
        ],
        'budgetPlanItems': [
          {
            'yearMonth': '2026-07',
            'categoryName': 'Ăn ngoài',
            'categoryId': 'food_out',
            'plannedLimit': 3000000,
            'alertThreshold': 80,
            'suggestedLimit': 2500000,
            'baseLimit': 3000000,
            'lastMonthSpent': 2800000,
            'wasOverBudgetLastMonth': false,
            'recommendation': 'keep',
          }
        ],
      };

      final backup = BackupData.fromJson(v5Json);

      expect(backup.schemaVersion, 5);
      expect(backup.budgetPlans.length, 1);
      expect(backup.budgetPlans.first.yearMonth, '2026-07');
      expect(backup.budgetPlans.first.plannedTotalBudget, 15000000);
      expect(backup.budgetPlans.first.status, 'draft');
      expect(backup.budgetPlanItems.length, 1);
      expect(backup.budgetPlanItems.first.categoryName, 'Ăn ngoài');
      expect(backup.budgetPlanItems.first.plannedLimit, 3000000);
      expect(backup.budgetPlanItems.first.recommendation, 'keep');
    });

    test('v4 JSON missing budgetPlans defaults to [] (ADR-0026 compat)', () {
      // Simulate v4 JSON: no budgetPlans/budgetPlanItems fields
      final v4Json = {
        'appId': 'qlct.app',
        'schemaVersion': 4,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        'budgetSnapshots': <Map<String, dynamic>>[],
        // no 'budgetPlans' field
        // no 'budgetPlanItems' field
      };

      final backup = BackupData.fromJson(v4Json);

      expect(backup.schemaVersion, 4);
      expect(backup.budgetPlans, isEmpty);
      expect(backup.budgetPlanItems, isEmpty);
    });

    test('v7 JSON with BudgetSnapshot missing carryAmount defaults to 0 (ADR-0032 compat)', () {
      // Simulate v7 backup (before carryAmount): snapshot has no carryAmount field
      final v7Json = {
        'appId': 'qlct.app',
        'schemaVersion': 7,
        'exportedAt': '2026-06-01T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        'budgetSnapshots': [
          {
            'yearMonth': '2026-05',
            'categoryName': 'Ăn ngoài',
            'categoryId': 'food_out',
            'limitAmount': 1000000,
            'alertThreshold': 80,
            'createdAt': '2026-06-01T00:00:00.000Z',
            // no carryAmount field — legacy v7 backup
          }
        ],
        'budgetPlans': <Map<String, dynamic>>[],
        'budgetPlanItems': <Map<String, dynamic>>[],
        'categories': <Map<String, dynamic>>[],
      };

      final backup = BackupData.fromJson(v7Json);

      expect(backup.schemaVersion, 7);
      expect(backup.budgetSnapshots.length, 1);
      expect(backup.budgetSnapshots.first.carryAmount, 0,
          reason: 'carryAmount must default to 0 when missing from older backup');
    });

    test('BudgetSnapshot with carryAmount is accessible in BackupData', () {
      // Verify BudgetSnapshot with carryAmount can be stored in BackupData
      final snapshotWithCarry = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        limitAmount: 1000000,
        alertThreshold: 80,
        createdAt: DateTime.parse('2026-06-01T00:00:00.000Z'),
        carryAmount: 300000,
      );

      final backup = BackupData(
        appId: 'qlct.app',
        schemaVersion: 8,
        exportedAt: '2026-06-01T10:00:00.000Z',
        appVersion: '1.0.0',
        budgetSnapshots: [snapshotWithCarry],
      );

      expect(backup.budgetSnapshots.length, 1);
      expect(backup.budgetSnapshots.first.carryAmount, 300000);

      // Verify v7 backup without carryAmount defaults to 0
      final snapshotDefault = BudgetSnapshot(
        yearMonth: '2026-04',
        categoryName: 'Cà phê',
        categoryId: 'ca_phe',
        limitAmount: 500000,
        alertThreshold: 80,
        createdAt: DateTime.parse('2026-05-01T00:00:00.000Z'),
      );

      final backup2 = BackupData(
        appId: 'qlct.app',
        schemaVersion: 8,
        exportedAt: '2026-06-01T10:00:00.000Z',
        appVersion: '1.0.0',
        budgetSnapshots: [snapshotDefault],
      );

      expect(backup2.budgetSnapshots.first.carryAmount, 0);
    });

    // ===== ADR-0037: v8 → v9 backup schema (deletedAt on Category) =====

    test('v8 JSON missing deletedAt on Category defaults to null (ADR-0037 compat)',
        () {
      // Simulate v8 backup: category has no deletedAt field.
      final v8Json = {
        'appId': 'qlct.app',
        'schemaVersion': 8,
        'exportedAt': '2026-06-10T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        'budgetSnapshots': <Map<String, dynamic>>[],
        'budgetPlans': <Map<String, dynamic>>[],
        'budgetPlanItems': <Map<String, dynamic>>[],
        'categories': [
          {
            'id': 'food_out',
            'name': 'Ăn ngoài',
            'normalizedName': 'an ngoai',
            'emoji': '🍜',
            'kind': 'spending',
            'budgetBehavior': 'flexible',
            'quickAmountMin': 30000,
            'quickAmountDefault': 50000,
            'quickAmountMax': 200000,
            'voicePhrases': <String>[],
            'sortOrder': 10,
            'isSystem': false,
            'isArchived': false,
            'createdAt': '2026-06-01T00:00:00.000Z',
            'updatedAt': '2026-06-01T00:00:00.000Z',
            // no deletedAt field — legacy v8 backup
          }
        ],
      };

      final backup = BackupData.fromJson(v8Json);

      expect(backup.schemaVersion, 8);
      expect(backup.categories.length, 1);
      expect(backup.categories.first.id, 'food_out');
      expect(backup.categories.first.deletedAt, isNull,
          reason: 'deletedAt must default to null when missing from v8 backup');
    });

    test('v9 JSON with soft-deleted Category parses with deletedAt preserved (ADR-0037)',
        () {
      // v9 backup where one category is soft-deleted (in trash). The restore
      // path goes BackupData.fromJson(...) → restore service, so we test the
      // parse path directly. (Round-trip via toJson is a separate concern
      // tracked outside this test.)
      final v9Json = {
        'appId': 'qlct.app',
        'schemaVersion': 9,
        'exportedAt': '2026-06-13T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': <Map<String, dynamic>>[],
        'budgets': <Map<String, dynamic>>[],
        'recurringTransactions': <Map<String, dynamic>>[],
        'quickTemplates': <Map<String, dynamic>>[],
        'budgetSnapshots': <Map<String, dynamic>>[],
        'budgetPlans': <Map<String, dynamic>>[],
        'budgetPlanItems': <Map<String, dynamic>>[],
        'categories': [
          {
            'id': 'food_out',
            'name': 'Ăn ngoài',
            'normalizedName': 'an ngoai',
            'emoji': '🍜',
            'kind': 'spending',
            'budgetBehavior': 'flexible',
            'quickAmountMin': 30000,
            'quickAmountDefault': 50000,
            'quickAmountMax': 200000,
            'voicePhrases': <String>[],
            'sortOrder': 10,
            'isSystem': true,
            'isArchived': false,
            'deletedAt': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
          {
            'id': 'old_brand',
            'name': 'Thương hiệu cũ',
            'normalizedName': 'thuong hieu cu',
            'emoji': '🏷️',
            'kind': 'spending',
            'budgetBehavior': 'flexible',
            'quickAmountMin': 10000,
            'quickAmountDefault': 20000,
            'quickAmountMax': 100000,
            'voicePhrases': <String>[],
            'sortOrder': 50,
            'isSystem': false,
            'isArchived': false,
            'deletedAt': '2026-06-12T14:30:00.000Z',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-06-12T14:30:00.000Z',
          },
        ],
      };

      final backup = BackupData.fromJson(v9Json);

      expect(backup.schemaVersion, 9);
      expect(backup.categories.length, 2);

      final active = backup.categories.firstWhere((c) => c.id == 'food_out');
      expect(active.deletedAt, isNull);

      final trashed = backup.categories.firstWhere((c) => c.id == 'old_brand');
      expect(trashed.deletedAt, isNotNull);
      expect(trashed.deletedAt!.toIso8601String(),
          '2026-06-12T14:30:00.000Z',
          reason: 'soft-delete state must survive backup import');
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/quick_template.dart';

void main() {
  group('BackupData', () {
    final sampleTx = Transaction(
      id: 'tx-1',
      amount: 50000,
      category: 'Cà phê',
      emoji: '☕',
      date: DateTime(2026, 6, 1, 8, 0),
      note: 'Test note',
    );

    final sampleBudget = Budget(
      id: 'b-1',
      categoryName: 'Ăn ngoài',
      monthlyLimit: 3000000,
      alertThreshold: 80,
      createdAt: DateTime(2026, 1, 1),
    );

    final sampleRecurring = RecurringTransaction(
      id: 'r-1',
      categoryName: 'Subscription',
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

    test('currentSchemaVersion is 3 (ADR-0023)', () {
      expect(currentSchemaVersion, 3);
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
  });
}
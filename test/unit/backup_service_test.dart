import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/repositories/budget_repository.dart';
import 'package:qlct/repositories/recurring_repository.dart';
import 'package:qlct/services/backup_service.dart';
import 'package:qlct/services/storage_service.dart';

class MockTransactionRepo extends Mock implements TransactionRepository {}

class MockBudgetRepo extends Mock implements BudgetRepository {}

class MockRecurringRepo extends Mock implements RecurringRepository {}

class MockStorageService extends Mock implements StorageService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late MockTransactionRepo txRepo;
  late MockBudgetRepo budgetRepo;
  late MockRecurringRepo recurringRepo;
  late MockStorageService storageService;
  late BackupService service;

  setUp(() {
    txRepo = MockTransactionRepo();
    budgetRepo = MockBudgetRepo();
    recurringRepo = MockRecurringRepo();
    storageService = MockStorageService();
    // _dbHelper is unused by createBackup/validate/generateSampleData but
    // required by the constructor. Pass null-safe stub.
    service = BackupService(
      txRepo,
      budgetRepo,
      recurringRepo,
      storageService,
      MockDatabaseHelper(), // dummy — not exercised by these tests
    );

    registerFallbackValue(Transaction(
      id: 'fallback',
      amount: 0,
      category: '',
      emoji: '',
      date: DateTime.now(),
    ));
    registerFallbackValue(Budget(
      id: 'fallback',
      categoryName: '',
      monthlyLimit: 0,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(RecurringTransaction(
      id: 'fallback',
      categoryName: '',
      amount: 0,
      frequency: 'daily',
      nextRunAt: DateTime.now(),
      isActive: false,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(<Transaction>[]);
    registerFallbackValue(<Budget>[]);
    registerFallbackValue(<RecurringTransaction>[]);
  });

  group('validate', () {
    test('valid backup JSON passes validation', () {
      final json = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': [],
        'budgets': [],
        'recurringTransactions': [],
      });

      final result = service.validate(json);
      expect(result.isValid, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.schemaVersion, 1);
    });

    test('non-JSON string returns error', () {
      final result = service.validate('not json at all {{{');
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('missing schemaVersion returns error', () {
      final json = jsonEncode({
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'transactions': [],
      });

      final result = service.validate(json);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('schemaVersion')), isTrue);
    });

    test('schemaVersion > current returns error', () {
      final json = jsonEncode({
        'schemaVersion': 999,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'transactions': [],
        'budgets': [],
        'recurringTransactions': [],
      });

      final result = service.validate(json);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('mới hơn')), isTrue);
    });

    test('transactions not a list returns error', () {
      final json = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'transactions': 'not a list',
        'budgets': [],
        'recurringTransactions': [],
      });

      final result = service.validate(json);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('transactions')), isTrue);
    });

    test('valid with full nested data passes validation', () {
      final json = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 15000000,
        'transactions': [
          {
            'id': 'tx-1',
            'amount': 50000,
            'category': 'Cà phê',
            'emoji': '☕',
            'date': '2026-06-01T08:00:00.000Z',
            'note': '',
            'sourceRecurringId': null,
          }
        ],
        'budgets': [
          {
            'id': 'b-1',
            'categoryName': 'Ăn ngoài',
            'monthlyLimit': 3000000,
            'alertThreshold': 80,
            'createdAt': '2026-01-01T00:00:00.000Z',
          }
        ],
        'recurringTransactions': [
          {
            'id': 'r-1',
            'categoryName': 'Subscription',
            'amount': 200000,
            'note': '',
            'frequency': 'monthly',
            'nextRunAt': '2026-07-01T00:00:00.000Z',
            'isActive': true,
            'createdAt': '2026-06-01T00:00:00.000Z',
          }
        ],
      });

      final result = service.validate(json);
      expect(result.isValid, isTrue);
      expect(result.data!.transactions.length, 1);
      expect(result.data!.budgets.length, 1);
      expect(result.data!.recurringTransactions.length, 1);
    });
  });

  // restore() behavior is covered by backup_service_atomic_test.dart
  // (atomic transaction, INSERT OR IGNORE merge, file size guard).

  group('createBackup', () {
    test('gathers data from all repos and storage', () async {
      when(() => txRepo.getAll()).thenAnswer((_) async => [
            Transaction(
              id: 'tx-1',
              amount: 50000,
              category: 'Cà phê',
              emoji: '☕',
              date: DateTime(2026, 6, 1),
            ),
          ]);
      when(() => budgetRepo.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'b-1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 3000000,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);
      when(() => recurringRepo.getAll()).thenAnswer((_) async => [
            RecurringTransaction(
              id: 'r-1',
              categoryName: 'Subscription',
              amount: 200000,
              frequency: 'monthly',
              nextRunAt: DateTime(2026, 7, 1),
              isActive: true,
              createdAt: DateTime(2026, 6, 1),
            ),
          ]);
      when(() => storageService.loadValue<int>('total_budget'))
          .thenReturn(15000000);

      final backup = await service.createBackup();

      expect(backup.schemaVersion, 1);
      expect(backup.transactions.length, 1);
      expect(backup.budgets.length, 1);
      expect(backup.recurringTransactions.length, 1);
      expect(backup.totalBudget, 15000000);
      expect(backup.appVersion, isNotEmpty);
      expect(backup.exportedAt, isNotEmpty);
    });

    test('handles empty state gracefully', () async {
      when(() => txRepo.getAll()).thenAnswer((_) async => []);
      when(() => budgetRepo.getAll()).thenAnswer((_) async => []);
      when(() => recurringRepo.getAll()).thenAnswer((_) async => []);
      when(() => storageService.loadValue<int>('total_budget'))
          .thenReturn(null);

      final backup = await service.createBackup();

      expect(backup.transactions, isEmpty);
      expect(backup.budgets, isEmpty);
      expect(backup.recurringTransactions, isEmpty);
      expect(backup.totalBudget, 0);
    });
  });

  group('generateSampleData', () {
    test('creates non-empty backup with expected structure', () async {
      final backup = await service.generateSampleData();

      expect(backup.schemaVersion, 1);
      expect(backup.transactions.length, 20);
      expect(backup.budgets.length, 3);
      expect(backup.recurringTransactions.length, 2);
      expect(backup.totalBudget, 15000000);

      final txIds = backup.transactions.map((t) => t.id).toSet();
      expect(txIds.length, 20);

      final budgetCats = backup.budgets.map((b) => b.categoryName).toSet();
      expect(budgetCats,
          containsAll(['Ăn ngoài', 'Cà phê', 'Mua online']));
    });
  });
}

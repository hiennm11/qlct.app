// Slice 3 from ADR-0010: atomic restore + compact JSON + file size guard
//
// Verifies:
// - FileTooLargeException is exported with correct message
// - restore(replace) is atomic — clear + insert in one transaction
// - restore(merge) uses INSERT OR IGNORE (skips duplicates, no O(N) ID load)
// - restore(replace) inserts all rows (table was cleared)
// - restore preserves existing totalBudget in merge when set
// - restore handles empty data gracefully

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi, databaseFactory;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/repositories/budget_repository.dart';
import 'package:qlct/repositories/recurring_repository.dart';
import 'package:qlct/services/backup_service.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTransactionRepo extends Mock implements TransactionRepository {}

class MockBudgetRepo extends Mock implements BudgetRepository {}

class MockRecurringRepo extends Mock implements RecurringRepository {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late DatabaseHelper dbHelper;
  late BackupService backupService;
  late MockTransactionRepo mockTxRepo;
  late MockBudgetRepo mockBudgetRepo;
  late MockRecurringRepo mockRecurringRepo;
  late MockStorageService mockStorage;

  setUpAll(() {
    sqfliteFfiInit();
    registerFallbackValue(Transaction(
      id: 'fallback',
      amount: 0,
      category: '',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
    registerFallbackValue(Budget(
      id: 'fallback',
      categoryName: '',
      monthlyLimit: 0,
      alertThreshold: 80,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(RecurringTransaction(
      id: 'fallback',
      categoryName: '',
      amount: 0,
      note: '',
      frequency: 'monthly',
      nextRunAt: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    ));
  });

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    dbHelper = DatabaseHelper();
    // Force init (creates tables via onCreate)
    await dbHelper.database;

    // Clean rows between tests
    final db = await dbHelper.database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('recurring_transactions');

    SharedPreferences.setMockInitialValues({});

    mockTxRepo = MockTransactionRepo();
    mockBudgetRepo = MockBudgetRepo();
    mockRecurringRepo = MockRecurringRepo();
    mockStorage = MockStorageService();

    backupService = BackupService(
      mockTxRepo,
      mockBudgetRepo,
      mockRecurringRepo,
      mockStorage,
      dbHelper,
    );
  });

  group('FileTooLargeException', () {
    test('exposes message via toString and message field', () {
      const ex = FileTooLargeException('Test message');
      expect(ex.message, 'Test message');
      expect(ex.toString(), 'Test message');
    });
  });

  group('atomic restore', () {
    test('replace mode inserts all rows and clears old data', () async {
      // Pre-existing row that should be wiped by replace
      final db = await dbHelper.database;
      await db.insert('transactions', {
        'id': 'old-tx',
        'amount': 1000,
        'category': 'Old',
        'emoji': '',
        'date': '2026-01-01T00:00:00.000',
        'note': '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      final backupData = BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        totalBudget: 15000000,
        transactions: [
          Transaction(
            id: 'tx-1',
            amount: 50000,
            category: 'Ăn ngoài',
            emoji: '🍜',
            date: DateTime(2026, 6, 1),
            note: '',
          ),
        ],
        budgets: [],
        recurringTransactions: [],
      );

      // Restore no longer calls the repos for the actual write — it goes
      // straight to SQLite via _dbHelper.runInTransaction. These mocks
      // exist only to satisfy createBackup() if other tests invoke it.
      when(() => mockTxRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockBudgetRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});

      final result =
          await backupService.restore(backupData, RestoreMode.replace);

      expect(result.success, isTrue);
      expect(result.transactionsImported, 1);

      // Old row gone, new row present
      final rows = await db.query('transactions');
      expect(rows.length, 1);
      expect(rows.first['id'], 'tx-1');
      expect(rows.first['amount'], 50000);
    });

    test('merge mode uses INSERT OR IGNORE — skips duplicates', () async {
      // Pre-existing row with a known ID
      final db = await dbHelper.database;
      await db.insert('transactions', {
        'id': 'existing-tx',
        'amount': 99999,
        'category': 'Existing',
        'emoji': '',
        'date': '2026-06-01T00:00:00.000',
        'note': '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Backup: 1 existing ID (should be skipped) + 1 new ID
      final backupData = BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        totalBudget: 15000000,
        transactions: [
          Transaction(
            id: 'existing-tx',
            amount: 1,
            category: 'Should Skip',
            emoji: '',
            date: DateTime(2026, 6, 1),
            note: '',
          ),
          Transaction(
            id: 'new-tx',
            amount: 50000,
            category: 'New',
            emoji: '🆕',
            date: DateTime(2026, 6, 1),
            note: '',
          ),
        ],
        budgets: [],
        recurringTransactions: [],
      );

      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(0);
      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});

      final result =
          await backupService.restore(backupData, RestoreMode.merge);

      expect(result.success, isTrue);
      // Only 1 new transaction imported (existing-tx is skipped)
      expect(result.transactionsImported, 1);

      // Verify: existing-tx still has amount 99999 (not overwritten)
      final rows = await db.query('transactions', orderBy: 'id');
      expect(rows.length, 2);
      final existing = rows.firstWhere((r) => r['id'] == 'existing-tx');
      expect(existing['amount'], 99999); // unchanged
      final newTx = rows.firstWhere((r) => r['id'] == 'new-tx');
      expect(newTx['amount'], 50000);
    });

    test('restore handles empty backup data', () async {
      final backupData = BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        transactions: [],
        budgets: [],
        recurringTransactions: [],
      );

      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});

      final result =
          await backupService.restore(backupData, RestoreMode.replace);

      expect(result.success, isTrue);
      expect(result.transactionsImported, 0);
      expect(result.budgetsImported, 0);
      expect(result.recurringsImported, 0);
    });

    test('merge preserves existing totalBudget if already set', () async {
      final backupData = BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        totalBudget: 99999999,
        transactions: [],
        budgets: [],
        recurringTransactions: [],
      );

      // Existing totalBudget is 20M — should NOT be overwritten
      when(() => mockStorage.loadValue<int>('total_budget'))
          .thenReturn(20000000);

      await backupService.restore(backupData, RestoreMode.merge);

      verifyNever(() => mockStorage.saveValue('total_budget', any()));
    });

    test('merge inserts all rows when totalBudget is currently 0', () async {
      // Pre-populate a budget row to verify merge touches the budgets table
      final db = await dbHelper.database;
      await db.insert('budgets', {
        'id': 'existing-budget',
        'category_name': 'OldCat',
        'monthly_limit': 100,
        'alert_threshold': 80,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      final backupData = BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        totalBudget: 5000000,
        transactions: [],
        budgets: [
          Budget(
            id: 'new-budget',
            categoryName: 'NewCat',
            monthlyLimit: 500,
            alertThreshold: 80,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        recurringTransactions: [],
      );

      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(0);
      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});

      final result =
          await backupService.restore(backupData, RestoreMode.merge);

      expect(result.success, isTrue);
      expect(result.budgetsImported, 1);

      // Both rows present (old one untouched, new one inserted)
      final rows = await db.query('budgets', orderBy: 'id');
      expect(rows.length, 2);
      expect(rows.firstWhere((r) => r['id'] == 'existing-budget')['category_name'],
          'OldCat');
      expect(rows.firstWhere((r) => r['id'] == 'new-budget')['category_name'],
          'NewCat');
    });
  });
}

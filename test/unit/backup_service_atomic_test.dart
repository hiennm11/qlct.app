// Slice 3 from ADR-0010: atomic restore + compact JSON + file size guard
//
// Verifies:
// - FileTooLargeException is exported with correct message
// - restore(replace) is atomic — clear + insert in one transaction
// - restore(merge) uses INSERT OR IGNORE (skips duplicates, no O(N) ID load)
// - restore(replace) inserts all rows (table was cleared)
// - restore preserves existing totalBudget in merge when set
// - restore handles empty data gracefully
// - ADR-0019: quick templates are restored in both merge and replace modes

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi, databaseFactory;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/quick_template_local_datasource.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/services/backup_service.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTransactionDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockBudgetDataSource extends Mock implements BudgetLocalDataSource {}

class MockRecurringDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockQuickTemplateDataSource extends Mock
    implements QuickTemplateLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late DatabaseHelper dbHelper;
  late BackupService backupService;
  late MockTransactionDataSource mockTxRepo;
  late MockBudgetDataSource mockBudgetRepo;
  late MockRecurringDataSource mockRecurringRepo;
  late MockStorageService mockStorage;
  late String dbPath;
  late Directory tempDir;

setUpAll(() {
    sqfliteFfiInit();
    registerFallbackValue(Transaction(
      id: 'fallback',
      amount: 0,
      category: 'test',
      emoji: '🍜',
      date: DateTime.now(),
      note: 'fallback',
    ));
    registerFallbackValue(Budget(
      id: 'fallback',
      categoryName: 'test',
      monthlyLimit: 0,
      alertThreshold: 80,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(RecurringTransaction(
      id: 'fallback',
      categoryName: 'test',
      amount: 0,
      note: 'fallback',
      frequency: 'monthly',
      nextRunAt: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(QuickTemplate(
      id: 'fallback',
      title: 'fallback',
      amount: 0,
      categoryName: 'test',
      note: 'fallback',
      emoji: '🍜',
      isPinned: false,
      usageCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('backup_test_');
    dbPath = p.join(tempDir.path,
        'qlct_backup_test_${DateTime.now().microsecondsSinceEpoch}.db');

    dbHelper = DatabaseHelper();
    dbHelper.testPathOverride = dbPath;
    // Force init (creates tables via onCreate)
    await dbHelper.database;

    // Clean rows between tests
    final db = await dbHelper.database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('recurring_transactions');
    await db.delete('quick_templates');

    SharedPreferences.setMockInitialValues({});

    mockTxRepo = MockTransactionDataSource();
    mockBudgetRepo = MockBudgetDataSource();
    mockRecurringRepo = MockRecurringDataSource();
    mockStorage = MockStorageService();

    backupService = BackupService(
      mockTxRepo,
      mockBudgetRepo,
      mockRecurringRepo,
      MockQuickTemplateDataSource(),
      mockStorage,
      dbHelper,
    );
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
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
        schemaVersion: 2,
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
        quickTemplates: [],
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
        schemaVersion: 2,
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
        quickTemplates: [],
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
        schemaVersion: 2,
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
      expect(result.quickTemplatesImported, 0);
    });

    test('merge preserves existing totalBudget if already set', () async {
      final backupData = BackupData(
        schemaVersion: 2,
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
        schemaVersion: 2,
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

    test('ADR-0019: replace mode restores quick templates', () async {
      final db = await dbHelper.database;

      final backupData = BackupData(
        schemaVersion: 2,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        transactions: [],
        budgets: [],
        recurringTransactions: [],
        quickTemplates: [
          QuickTemplate(
            id: 'qt-1',
            title: 'Cơm trưa',
            amount: 35000,
            categoryName: 'Ăn ngoài',
            emoji: '🍜',
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
          ),
          QuickTemplate(
            id: 'qt-2',
            title: 'Cà phê sáng',
            amount: 25000,
            categoryName: 'Cà phê',
            emoji: '☕',
            createdAt: DateTime(2026, 6, 2),
            updatedAt: DateTime(2026, 6, 2),
          ),
        ],
      );

      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});

      final result =
          await backupService.restore(backupData, RestoreMode.replace);

      expect(result.success, isTrue);
      expect(result.quickTemplatesImported, 2);

      final rows = await db.query('quick_templates', orderBy: 'id');
      expect(rows.length, 2);
      expect(rows.first['id'], 'qt-1');
      expect(rows.first['title'], 'Cơm trưa');
      expect(rows.first['amount'], 35000);
      expect(rows.last['id'], 'qt-2');
      expect(rows.last['title'], 'Cà phê sáng');
    });

    test('ADR-0019: merge mode skips duplicate quick templates', () async {
      final db = await dbHelper.database;

      // Pre-existing quick template
      await db.insert('quick_templates', {
        'id': 'existing-qt',
        'title': 'Cơm trưa',
        'amount': 35000,
        'category_name': 'Ăn ngoài',
        'note': '',
        'emoji': '🍜',
        'is_pinned': 1,
        'usage_count': 10,
        'last_used_at': null,
        'created_at': DateTime(2026, 6, 1).toIso8601String(),
        'updated_at': DateTime(2026, 6, 1).toIso8601String(),
      });

      final backupData = BackupData(
        schemaVersion: 2,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        appVersion: '1.0.0',
        transactions: [],
        budgets: [],
        recurringTransactions: [],
        quickTemplates: [
          QuickTemplate(
            id: 'existing-qt',
            title: 'Changed Title',
            amount: 99999,
            categoryName: 'Khác',
            emoji: '📌',
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
          ),
          QuickTemplate(
            id: 'new-qt',
            title: 'Cà phê sáng',
            amount: 25000,
            categoryName: 'Cà phê',
            emoji: '☕',
            createdAt: DateTime(2026, 6, 2),
            updatedAt: DateTime(2026, 6, 2),
          ),
        ],
      );

      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(0);
      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});

      final result =
          await backupService.restore(backupData, RestoreMode.merge);

      expect(result.success, isTrue);
      expect(result.quickTemplatesImported, 1); // only new-qt

      final rows = await db.query('quick_templates', orderBy: 'id');
      expect(rows.length, 2);
      // existing-qt should still have original amount (skipped via INSERT OR IGNORE)
      final existing =
          rows.firstWhere((r) => r['id'] == 'existing-qt');
      expect(existing['amount'], 35000);
      expect(existing['title'], 'Cơm trưa');
    });
  });
}

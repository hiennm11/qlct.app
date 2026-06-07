import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/services/backup_service.dart';
import 'package:qlct/services/storage_service.dart';

class MockTransactionDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockBudgetDataSource extends Mock implements BudgetLocalDataSource {}

class MockRecurringDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late MockTransactionDataSource txRepo;
  late MockBudgetDataSource budgetRepo;
  late MockRecurringDataSource recurringRepo;
  late MockStorageService storageService;
  late BackupService service;

  setUp(() {
    txRepo = MockTransactionDataSource();
    budgetRepo = MockBudgetDataSource();
    recurringRepo = MockRecurringDataSource();
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

  group('validateFile (streaming parse)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('streaming parse produces same result as readAsString+jsonDecode',
        () async {
      final jsonMap = {
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 15000000,
        'transactions': [
          {
            'id': 'tx-stream-1',
            'amount': 50000,
            'category': 'Cà phê',
            'emoji': '☕',
            'date': '2026-06-01T08:00:00.000Z',
            'note': 'stream test',
            'sourceRecurringId': null,
          }
        ],
        'budgets': [
          {
            'id': 'b-stream-1',
            'categoryName': 'Ăn ngoài',
            'monthlyLimit': 3000000,
            'alertThreshold': 80,
            'createdAt': '2026-01-01T00:00:00.000Z',
          }
        ],
        'recurringTransactions': [
          {
            'id': 'r-stream-1',
            'categoryName': 'Subscription',
            'amount': 200000,
            'note': '',
            'frequency': 'monthly',
            'nextRunAt': '2026-07-01T00:00:00.000Z',
            'isActive': true,
            'createdAt': '2026-06-01T00:00:00.000Z',
          }
        ],
      };
      final jsonStr = jsonEncode(jsonMap);

      // Baseline: legacy readAsString+jsonDecode+validate path
      final legacyResult = service.validate(jsonStr);
      expect(legacyResult.isValid, isTrue,
          reason: 'baseline legacy validation must pass');

      // New: streaming parse from a real file on disk
      final file = File('${tempDir.path}/backup.json');
      await file.writeAsString(jsonStr);

      final streamResult = await service.validateFile(file);

      expect(streamResult.isValid, isTrue,
          reason: 'streaming validation must pass');
      expect(streamResult.errors, isEmpty);

      // Result data must be equivalent
      expect(streamResult.data, isNotNull);
      expect(streamResult.data!.schemaVersion,
          legacyResult.data!.schemaVersion);
      expect(streamResult.data!.totalBudget, legacyResult.data!.totalBudget);
      expect(streamResult.data!.transactions.length,
          legacyResult.data!.transactions.length);
      expect(streamResult.data!.budgets.length,
          legacyResult.data!.budgets.length);
      expect(streamResult.data!.recurringTransactions.length,
          legacyResult.data!.recurringTransactions.length);

      // Per-row equivalence
      expect(streamResult.data!.transactions.first.id, 'tx-stream-1');
      expect(streamResult.data!.transactions.first.amount, 50000);
      expect(streamResult.data!.budgets.first.categoryName, 'Ăn ngoài');
      expect(streamResult.data!.recurringTransactions.first.amount, 200000);
    });

    test('non-JSON file content returns FormatException-derived error',
        () async {
      final file = File('${tempDir.path}/bad.json');
      await file.writeAsString('not json at all {{{');

      final result = await service.validateFile(file);

      expect(result.isValid, isFalse);
      expect(result.data, isNull);
      expect(result.errors, isNotEmpty);
      expect(
        result.errors.any((e) => e.contains('JSON') || e.contains('hợp lệ')),
        isTrue,
      );
    });

    test('JSON that is not an object (e.g. bare array) returns error',
        () async {
      final file = File('${tempDir.path}/array.json');
      await file.writeAsString('[1, 2, 3]');

      final result = await service.validateFile(file);

      expect(result.isValid, isFalse);
      expect(result.data, isNull);
      expect(
        result.errors.any((e) => e.contains('JSON object hợp lệ')),
        isTrue,
      );
    });

    test('streamed parse of empty backup file is valid', () async {
      final emptyJson = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-06-05T10:00:00.000Z',
        'appVersion': '1.0.0',
        'totalBudget': 0,
        'transactions': [],
        'budgets': [],
        'recurringTransactions': [],
      });
      final file = File('${tempDir.path}/empty.json');
      await file.writeAsString(emptyJson);

      final result = await service.validateFile(file);

      expect(result.isValid, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.transactions, isEmpty);
      expect(result.data!.budgets, isEmpty);
      expect(result.data!.recurringTransactions, isEmpty);
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

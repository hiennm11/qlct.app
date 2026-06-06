import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/sqlite_transaction_datasource.dart';
import 'package:qlct/data/migrations/shared_prefs_to_sqlite.dart';
import 'package:qlct/core/constants.dart';

void main() {
  late DatabaseHelper dbHelper;
  late TransactionLocalDataSource dataSource;
  late MigrationService migrationService;
  const testTransactionsKey = 'transactions';

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // Use in-memory database for testing
    databaseFactory = databaseFactoryFfi;
    dbHelper = DatabaseHelper();
    await dbHelper.database; // force creation

    // Wipe any existing transactions
    final db = await dbHelper.database;
    await db.delete('transactions');

    dataSource = SqliteTransactionDataSource(dbHelper);
    migrationService = MigrationService(dbHelper);

    // Set up SharedPreferences mock values
    SharedPreferences.setMockInitialValues({});
  });

  group('MigrationService', () {
    test('migrates old SharedPreferences transactions to SQLite', () async {
      // Arrange: write old-format transactions to SharedPreferences
      const jsonString =
          '[{"id":1749001234567,"amount":50000,"category":"Ăn ngoài","emoji":"🍜","date":"2026-06-01T12:00:00.000","note":"Phở sáng"},{"id":1749001234568,"amount":20000,"category":"Cà phê","emoji":"☕","date":"2026-06-01T14:00:00.000","note":""}]';

      SharedPreferences.setMockInitialValues({
        testTransactionsKey: jsonString,
      });

      // Act
      await migrationService.migrate();

      // Assert: verify transactions in SQLite
      final transactions = await dataSource.getAll();
      expect(transactions.length, 2);
      // ordered by created_at DESC (later insert first)
      expect(transactions[0].amount, 20000);
      expect(transactions[0].id, '1749001234568');
      expect(transactions[1].amount, 50000);
      expect(transactions[1].id, '1749001234567'); // int → String

      // Assert: migration flag set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('migrated_to_sqlite_v1'), isTrue);
      expect(prefs.getBool('migrated_to_sqlite_v1'), isTrue);
    });

    test('skip migration when flag already set', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'migrated_to_sqlite_v1': true,
        testTransactionsKey:
            '[{"id":999,"amount":1000,"category":"Test","emoji":"🧪","date":"2026-01-01T00:00:00.000","note":""}]',
      });

      // Act
      await migrationService.migrate();

      // Assert: nothing migrated
      final transactions = await dataSource.getAll();
      expect(transactions.isEmpty, isTrue);

      // Flag remains set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_to_sqlite_v1'), isTrue);
    });

    test('handles empty SharedPreferences gracefully', () async {
      // Arrange: no transactions key
      SharedPreferences.setMockInitialValues({});

      // Act
      await migrationService.migrate();

      // Assert: no crash, flag set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_to_sqlite_v1'), isTrue);

      final transactions = await dataSource.getAll();
      expect(transactions.isEmpty, isTrue);
    });

    test('skips corrupt rows in old JSON', () async {
      // Arrange: mixed valid and invalid rows
      const jsonString =
          '[{"id":1,"amount":50000,"category":"Test","emoji":"🧪","date":"2026-01-01T00:00:00.000","note":""},{"corrupt":"no id field"}]';

      SharedPreferences.setMockInitialValues({
        testTransactionsKey: jsonString,
      });

      // Act: should not throw
      await migrationService.migrate();

      // Assert: only valid row migrated
      final transactions = await dataSource.getAll();
      expect(transactions.length, 1);
      expect(transactions[0].id, '1');
      expect(transactions[0].amount, 50000);

      // Flag should still be set (skip corrupt, proceed with valid)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_to_sqlite_v1'), isTrue);
    });

    test('handles completely corrupt JSON without crash', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        testTransactionsKey: 'this is not valid JSON at all',
      });

      // Act: should not throw
      await migrationService.migrate();

      // Assert: flag set (prevents infinite retry)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_to_sqlite_v1'), isTrue);

      final transactions = await dataSource.getAll();
      expect(transactions.isEmpty, isTrue);
    });

    test('backs up old SharedPreferences data before clear', () async {
      // Arrange
      const jsonString =
          '[{"id":1,"amount":50000,"category":"Test","emoji":"🧪","date":"2026-01-01T00:00:00.000","note":""}]';
      SharedPreferences.setMockInitialValues({
        testTransactionsKey: jsonString,
      });

      // Act
      await migrationService.migrate();

      // Assert: backup key exists with original data
      final prefs = await SharedPreferences.getInstance();
      final backup = prefs.getString('${testTransactionsKey}_backup_v1');
      expect(backup, isNotNull);
      expect(backup, jsonString);

      // Original key is removed
      expect(prefs.getString(testTransactionsKey), isNull);
    });

    test('handles partial migration retry with INSERT OR IGNORE', () async {
      // Arrange: first migration partially succeeded (flag NOT set, data exists)
      const jsonString =
          '[{"id":1749001234567,"amount":50000,"category":"Test","emoji":"🧪","date":"2026-01-01T00:00:00.000","note":""}]';
      SharedPreferences.setMockInitialValues({
        testTransactionsKey: jsonString,
        // NO flag - simulates partial failure scenario
      });

      // Manually insert one row to simulate partial migration
      final db = await dbHelper.database;
      await db.insert('transactions', {
        'id': '1749001234567',
        'amount': 50000,
        'category': 'Test',
        'emoji': '🧪',
        'date': '2026-01-01T00:00:00.000',
        'note': '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Act: run migration again
      await migrationService.migrate();

      // Assert: no duplicate, still 1 row
      final transactions = await dataSource.getAll();
      expect(transactions.length, 1);

      // Flag is now set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_to_sqlite_v1'), isTrue);
    });
  });
}
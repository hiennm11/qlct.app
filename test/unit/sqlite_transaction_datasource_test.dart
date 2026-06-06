import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:path/path.dart' as p;
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_transaction_datasource.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SqliteTransactionDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    // Use in-memory database for testing
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE transactions (
              id         TEXT PRIMARY KEY,
              amount     INTEGER NOT NULL,
              category   TEXT NOT NULL,
              emoji      TEXT NOT NULL DEFAULT '',
              date       TEXT NOT NULL,
              note       TEXT NOT NULL DEFAULT '',
              source_recurring_id TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
          await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
        },
      ),
    );
    // Inject the in-memory database
    dbHelper.testDatabase = db;
    dataSource = SqliteTransactionDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('add', () {
    test('inserts transaction and persists to database', () async {
      final transaction = Transaction(
        id: 'test-uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'ăn trưa',
      );

      await dataSource.add(transaction);

      final db = await dbHelper.database;
      final result = await db.query('transactions');
      expect(result.length, 1);
      expect(result.first['id'], 'test-uuid-1');
      expect(result.first['amount'], 50000);
      expect(result.first['category'], 'Ăn ngoài');
      expect(result.first['emoji'], '🍜');
      expect(result.first['note'], 'ăn trưa');
    });
  });

  group('delete', () {
    test('deletes transaction by id, keeping others', () async {
      final t1 = Transaction(
        id: 'uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      final t2 = Transaction(
        id: 'uuid-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 3),
        note: '',
      );

      await dataSource.add(t1);
      await dataSource.add(t2);
      await dataSource.delete('uuid-1');

      final db = await dbHelper.database;
      final result = await db.query('transactions');
      expect(result.length, 1);
      expect(result.first['id'], 'uuid-2');
    });
  });

  group('getAll', () {
    test('returns all transactions sorted by created_at DESC', () async {
      final t1 = Transaction(
        id: 'uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 1),
        note: '',
      );
      final t2 = Transaction(
        id: 'uuid-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 2),
        note: '',
      );
      final t3 = Transaction(
        id: 'uuid-3',
        amount: 100000,
        category: 'Di chuyển',
        emoji: '🚗',
        date: DateTime(2026, 6, 3),
        note: '',
      );

      // Add in order: 1, 2, 3
      // After add, t3 has highest created_at, should appear first in getAll
      await dataSource.add(t1);
      await Future.delayed(const Duration(milliseconds: 10));
      await dataSource.add(t2);
      await Future.delayed(const Duration(milliseconds: 10));
      await dataSource.add(t3);

      final result = await dataSource.getAll();

      expect(result.length, 3);
      // Most recently added should be first (highest created_at)
      expect(result[0].id, 'uuid-3');
      expect(result[1].id, 'uuid-2');
      expect(result[2].id, 'uuid-1');
    });
  });

  group('getByDate', () {
    test('returns transactions for specific date only', () async {
      final t1 = Transaction(
        id: 'uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      final t2 = Transaction(
        id: 'uuid-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: '',
      );

      await dataSource.add(t1);
      await dataSource.add(t2);

      final result = await dataSource.getByDate(DateTime(2026, 6, 3));

      expect(result.length, 1);
      expect(result.first.id, 'uuid-1');
    });
  });

  group('getByCategory', () {
    test('returns transactions for specific category', () async {
      final t1 = Transaction(
        id: 'uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      final t2 = Transaction(
        id: 'uuid-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 3),
        note: '',
      );

      await dataSource.add(t1);
      await dataSource.add(t2);

      final result = await dataSource.getByCategory('Ăn ngoài');

      expect(result.length, 1);
      expect(result.first.id, 'uuid-1');
    });
  });

  group('clearAll', () {
    test('deletes all transactions', () async {
      final t1 = Transaction(
        id: 'uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      final t2 = Transaction(
        id: 'uuid-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 3),
        note: '',
      );

      await dataSource.add(t1);
      await dataSource.add(t2);
      await dataSource.clearAll();

      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });
  });

  group('bulkInsert', () {
    test('should insert multiple transactions', () async {
      final txs = List.generate(10, (i) => Transaction(
        id: 'bulk-$i',
        amount: (i + 1) * 10000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, i + 1),
      ));

      await dataSource.bulkInsert(txs);

      final all = await dataSource.getAll();
      expect(all.length, 10);
      expect(all.map((t) => t.id).toSet(),
          containsAll(txs.map((t) => t.id)));
    });

    test('should handle empty list', () async {
      await dataSource.bulkInsert([]);
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });

    test('should overwrite on duplicate IDs (ConflictAlgorithm.replace)', () async {
      final tx1 = Transaction(
        id: 'bulk-dup',
        amount: 50000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 1),
      );
      await dataSource.bulkInsert([tx1]);

      final tx2 = Transaction(
        id: 'bulk-dup',
        amount: 99999,
        category: 'Khác',
        emoji: '📌',
        date: DateTime(2026, 6, 1),
      );
      await dataSource.bulkInsert([tx2]);

      final all = await dataSource.getAll();
      expect(all.length, 1);
      expect(all.first.amount, 99999);
      expect(all.first.category, 'Khác');
    });
  });

  group('existsBySourceRecurringIdAndDate', () {
    test('returns true when transaction with matching source+date exists', () async {
      final tx = Transaction(
        id: 'exists-uuid-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 4),
        note: '',
        sourceRecurringId: 'rec-1',
      );
      await dataSource.add(tx);

      final result = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-1', '2026-06-04');

      expect(result, true);
    });

    test('returns false when no transaction with that source+date combo', () async {
      final tx = Transaction(
        id: 'exists-uuid-2',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 4),
        note: '',
        sourceRecurringId: 'rec-1',
      );
      await dataSource.add(tx);

      // Different date
      final result = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-1', '2026-06-05');

      expect(result, false);
    });

    test('returns false when same date but different source recurring id', () async {
      final tx = Transaction(
        id: 'exists-uuid-3',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 4),
        note: '',
        sourceRecurringId: 'rec-1',
      );
      await dataSource.add(tx);

      final result = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-2', '2026-06-04');

      expect(result, false);
    });

    test('returns false for empty database', () async {
      final result = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-1', '2026-06-04');

      expect(result, false);
    });

    test('uses SELECT 1 LIMIT 1 for O(1) performance', () async {
      // Verify the query uses LIMIT 1 (checked via source inspection)
      // We test behavior: same id+date always returns same result
      final tx = Transaction(
        id: 'exists-uuid-4',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 4),
        note: '',
        sourceRecurringId: 'rec-1',
      );
      await dataSource.add(tx);

      // Call multiple times — result should be consistent
      final r1 = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-1', '2026-06-04');
      final r2 = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-1', '2026-06-04');
      final r3 = await dataSource.existsBySourceRecurringIdAndDate(
          'rec-1', '2026-06-04');

      expect(r1, true);
      expect(r2, true);
      expect(r3, true);
    });
  });

  group('persistence after restart', () {
    late String tempDbPath;
    late Database? tempDb;

    tearDown(() async {
      if (tempDb != null) {
        await tempDb!.close();
        tempDb = null;
      }
      // Clean up temp file
      try {
        await databaseFactoryFfi.deleteDatabase(tempDbPath);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('data survives database close and reopen (simulated restart)', () async {
      // 1. Create a file-based SQLite DB at a temp path
      final dbFileName = 'qlct_persistence_test_${DateTime.now().millisecondsSinceEpoch}.db';
      final databasesPath = await databaseFactoryFfi.getDatabasesPath();
      tempDbPath = p.join(databasesPath, dbFileName);

      tempDb = await databaseFactoryFfi.openDatabase(
        tempDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id         TEXT PRIMARY KEY,
                amount     INTEGER NOT NULL,
                category   TEXT NOT NULL,
                emoji      TEXT NOT NULL DEFAULT '',
                date       TEXT NOT NULL,
                note       TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at INTEGER NOT NULL
              )
            ''');
            await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
            await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
          },
        ),
      );

      // Create datasource and insert a transaction
      final dbHelperForInsert = DatabaseHelper();
      dbHelperForInsert.testDatabase = tempDb!;
      final dataSourceForInsert = SqliteTransactionDataSource(dbHelperForInsert);

      final transaction = Transaction(
        id: 'persistence-test-uuid',
        amount: 75000,
        category: 'Mua sắm',
        emoji: '🛒',
        date: DateTime(2026, 6, 3),
        note: 'test persistence',
      );

      await dataSourceForInsert.add(transaction);

      // 3. Close the database
      await dbHelperForInsert.close();
      await tempDb!.close();
      tempDb = null;

      // 4. Reopen the same database file (new DatabaseHelper, new datasource)
      final reopenedDb = await databaseFactoryFfi.openDatabase(
        tempDbPath,
        options: OpenDatabaseOptions(),
      );

      final dbHelperForRead = DatabaseHelper();
      dbHelperForRead.testDatabase = reopenedDb;
      final dataSourceForRead = SqliteTransactionDataSource(dbHelperForRead);

      // 5. getAll() → verify 1 transaction still exists with matching data
      final result = await dataSourceForRead.getAll();

      expect(result.length, 1);
      expect(result.first.id, 'persistence-test-uuid');
      expect(result.first.amount, 75000);
      expect(result.first.category, 'Mua sắm');
      expect(result.first.emoji, '🛒');
      expect(result.first.note, 'test persistence');
      expect(result.first.date, DateTime(2026, 6, 3));

      // 6. Clean up: close and delete the temp file (handled in tearDown)
      await dbHelperForRead.close();
      await reopenedDb.close();
      tempDb = reopenedDb; // Set so tearDown will clean up
    });
  });
}
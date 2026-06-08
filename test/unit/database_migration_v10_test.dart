// ADR-0025: DB v9 upgrades to v10 with budget_snapshots table.
// ADR-0025 §2: composite PK (year_month, category_name) rejects duplicates.
//
// IMPORTANT: this test exercises the REAL DatabaseHelper._onUpgrade path,
// not a duplicated in-test callback. The v9 file is created on disk at a
// unique path that DatabaseHelper reopens (via testPathOverride), so the
// production _onUpgrade is triggered end-to-end.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_budget_snapshot_datasource.dart';
import 'package:qlct/models/budget_snapshot.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('v10upgrade_');
    final dbFileName =
        'v10upgrade_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DB migration v9 → v10 (real DatabaseHelper)', () {
    test('v9 DB with budgets — upgrade creates budget_snapshots table', () async {
      // Step 1: create a v9 DB on disk (no budget_snapshots table).
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id                       TEXT PRIMARY KEY,
                amount                   INTEGER NOT NULL,
                category                 TEXT NOT NULL,
                emoji                    TEXT NOT NULL DEFAULT '',
                date                     TEXT NOT NULL,
                note                     TEXT NOT NULL DEFAULT '',
                source_recurring_id      TEXT,
                created_at               INTEGER NOT NULL,
                search_text_normalized   TEXT NOT NULL DEFAULT ''
              )
            ''');
            await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
            await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
            await db.execute('''
              CREATE TABLE budgets (
                id              TEXT PRIMARY KEY,
                category_name   TEXT NOT NULL,
                monthly_limit   INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL
              )
            ''');
            await db.execute(
                'CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_name)');
          },
        ),
      );

      // Seed a budget row
      await db.execute('''
        INSERT INTO budgets (id, category_name, monthly_limit, alert_threshold, created_at)
        VALUES ('b1', 'Ăn ngoài', 3000000, 80, 1759766400000)
      ''');
      await db.close();

      // Step 2: reopen via DatabaseHelper.database — _onUpgrade(db, 9, 10) fires
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV10 = await dbHelper.database;

      // Table created by the real _onUpgrade
      final tables = await dbV10.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_snapshots'");
      expect(tables.length, 1, reason: 'budget_snapshots table must exist after v9→v10');

      // Composite PK on (year_month, category_name)
      final pkInfo = await dbV10.rawQuery(
          "PRAGMA index_info('sqlite_autoindex_budget_snapshots_1')");
      expect(pkInfo.isNotEmpty, isTrue,
          reason: 'auto-index for composite PK should exist');

      // Step 3: verify insert works
      final now = DateTime.now().millisecondsSinceEpoch;
      await dbV10.execute('''
        INSERT INTO budget_snapshots (year_month, category_name, limit_amount, alert_threshold, created_at)
        VALUES ('2026-05', 'Ăn ngoài', 3000000, 80, $now)
      ''');
      final rows = await dbV10.rawQuery(
          'SELECT * FROM budget_snapshots WHERE year_month = ? AND category_name = ?',
          ['2026-05', 'Ăn ngoài']);
      expect(rows.length, 1);
      expect(rows.first['limit_amount'], 3000000);

      await dbHelper.close();
    });

    test('composite PK rejects duplicate (year_month, category_name)', () async {
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                amount INTEGER NOT NULL,
                category TEXT NOT NULL,
                emoji TEXT NOT NULL DEFAULT '',
                date TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at INTEGER NOT NULL,
                search_text_normalized TEXT NOT NULL DEFAULT ''
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
          },
        ),
      );
      await db.close();

      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV10 = await dbHelper.database;

      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert first row
      await dbV10.execute('''
        INSERT INTO budget_snapshots (year_month, category_name, limit_amount, alert_threshold, created_at)
        VALUES ('2026-05', 'Ăn ngoài', 3000000, 80, $now)
      ''');

      // Insert duplicate — should fail (UNIQUE constraint)
      try {
        await dbV10.execute('''
          INSERT INTO budget_snapshots (year_month, category_name, limit_amount, alert_threshold, created_at)
          VALUES ('2026-05', 'Ăn ngoài', 9999999, 80, $now)
        ''');
        fail('Expected SQLiteException for duplicate composite key');
      } on DatabaseException catch (e) {
        expect(e.toString().toLowerCase(), contains('unique'),
            reason: 'duplicate (year_month, category_name) must violate UNIQUE constraint');
      }

      // INSERT OR IGNORE skips the duplicate
      await dbV10.execute('''
        INSERT OR IGNORE INTO budget_snapshots (year_month, category_name, limit_amount, alert_threshold, created_at)
        VALUES ('2026-05', 'Ăn ngoài', 9999999, 80, $now)
      ''');
      final rows = await dbV10.rawQuery(
          'SELECT * FROM budget_snapshots WHERE year_month = ? AND category_name = ?',
          ['2026-05', 'Ăn ngoài']);
      expect(rows.length, 1);
      // Original value preserved (9999999 was ignored)
      expect(rows.first['limit_amount'], 3000000,
          reason: 'INSERT OR IGNORE must preserve original row, skip duplicate');

      await dbHelper.close();
    });

    test('v9 empty DB — upgrade creates table without error', () async {
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                amount INTEGER NOT NULL,
                category TEXT NOT NULL,
                emoji TEXT NOT NULL DEFAULT '',
                date TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at INTEGER NOT NULL,
                search_text_normalized TEXT NOT NULL DEFAULT ''
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
          },
        ),
      );
      await db.close();

      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV10 = await dbHelper.database;

      final tables = await dbV10.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_snapshots'");
      expect(tables.length, 1, reason: 'budget_snapshots table must exist on empty v9→v10');
      expect(
          await dbV10.rawQuery('SELECT COUNT(*) AS c FROM budget_snapshots'),
          [{'c': 0}]);
      await dbHelper.close();
    });
  });

  group('DB v10 fresh install (real DatabaseHelper)', () {
    test('fresh v10 install includes budget_snapshots table', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final db = await dbHelper.database;

      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_snapshots'");
      expect(tables.length, 1, reason: 'fresh v10 must have budget_snapshots in _onCreate');

      await dbHelper.close();
    });
  });

  group('SqliteBudgetSnapshotDataSource roundtrip', () {
    test('insert + getAll preserves data', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetSnapshotDataSource(dbHelper);
      final now = DateTime.now();

      await ds.upsert(BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: now,
      ));

      final all = await ds.getAll();
      expect(all.length, 1);
      expect(all.first.yearMonth, '2026-05');
      expect(all.first.categoryName, 'Ăn ngoài');
      expect(all.first.limitAmount, 3000000);

      await dbHelper.close();
    });

    test('getByYearMonth filters correctly', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetSnapshotDataSource(dbHelper);
      final now = DateTime.now();

      await ds.bulkUpsert([
        BudgetSnapshot(
          yearMonth: '2026-05',
          categoryName: 'Ăn ngoài',
          limitAmount: 3000000,
          alertThreshold: 80,
          createdAt: now,
        ),
        BudgetSnapshot(
          yearMonth: '2026-05',
          categoryName: 'Cà phê',
          limitAmount: 1000000,
          alertThreshold: 80,
          createdAt: now,
        ),
        BudgetSnapshot(
          yearMonth: '2026-04',
          categoryName: 'Ăn ngoài',
          limitAmount: 2500000,
          alertThreshold: 80,
          createdAt: now,
        ),
      ]);

      final maySnapshots = await ds.getByYearMonth('2026-05');
      expect(maySnapshots.length, 2);
      expect(maySnapshots.map((s) => s.categoryName).toSet(),
          {'Ăn ngoài', 'Cà phê'});

      final aprSnapshots = await ds.getByYearMonth('2026-04');
      expect(aprSnapshots.length, 1);
      expect(aprSnapshots.first.categoryName, 'Ăn ngoài');

      await dbHelper.close();
    });

    test('bulkUpsert + clearAll works', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetSnapshotDataSource(dbHelper);
      final now = DateTime.now();

      await ds.bulkUpsert([
        BudgetSnapshot(
          yearMonth: '2026-05',
          categoryName: 'Ăn ngoài',
          limitAmount: 3000000,
          alertThreshold: 80,
          createdAt: now,
        ),
      ]);
      expect(await ds.count(), 1);

      await ds.clearAll();
      expect(await ds.count(), 0);

      await dbHelper.close();
    });

    test('deleteByYearMonth removes only that month', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetSnapshotDataSource(dbHelper);
      final now = DateTime.now();

      await ds.bulkUpsert([
        BudgetSnapshot(
          yearMonth: '2026-05',
          categoryName: 'Ăn ngoài',
          limitAmount: 3000000,
          alertThreshold: 80,
          createdAt: now,
        ),
        BudgetSnapshot(
          yearMonth: '2026-04',
          categoryName: 'Ăn ngoài',
          limitAmount: 2500000,
          alertThreshold: 80,
          createdAt: now,
        ),
      ]);

      await ds.deleteByYearMonth('2026-05');

      final remaining = await ds.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.yearMonth, '2026-04');

      await dbHelper.close();
    });
  });
}
// ADR-0022: v8 DB upgrades to v9 with search_text_normalized column + index,
// existing rows are backfilled via Dart normalization.
//
// IMPORTANT: this test exercises the REAL DatabaseHelper._onUpgrade path,
// not a duplicated in-test callback. The v8 file is created on disk at a
// unique path that DatabaseHelper reopens (via testPathOverride), so the
// production _onUpgrade is triggered end-to-end. If the real migration code
// regresses, this test catches it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_transaction_datasource.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Each test gets its own temp file. DatabaseHelper reopens it via
    // testPathOverride, so the REAL _onUpgrade fires against a v8 file
    // we control. This sidesteps the FFI isolate locking the default
    // `qlct.db` file from previous test runs.
    tempDir = Directory.systemTemp.createTempSync('v8upgrade_');
    final dbFileName =
        'v8upgrade_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DB migration v8 → v9 (real DatabaseHelper)', () {
    test('v8 DB with rows — upgrade adds column+index, backfills, makes searchable',
        () async {
      // Step 1: create a v8 DB on disk (no search_text_normalized column).
      // Schema mirrors what DatabaseHelper._onCreate produced at version 8
      // (transactions + the v7 indexes; v9 column and index are absent).
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id                  TEXT PRIMARY KEY,
                amount              INTEGER NOT NULL,
                category            TEXT NOT NULL,
                emoji               TEXT NOT NULL DEFAULT '',
                date                TEXT NOT NULL,
                note                TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at          INTEGER NOT NULL
              )
            ''');
            await db.execute(
                'CREATE INDEX idx_transactions_date ON transactions(date)');
            await db.execute(
                'CREATE INDEX idx_transactions_category ON transactions(category)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
          },
        ),
      );

      // Step 2: seed v8 rows. The v8 schema has no search_text_normalized
      // column, so we do not insert one. The real _onUpgrade will backfill.
      await db.execute('''
        INSERT INTO transactions (id, amount, category, emoji, date, note, source_recurring_id, created_at)
        VALUES ('old-1', 50000, 'Cà phê', '☕', '2026-06-07T00:00:00.000', 'cà phê sáng', NULL, 1759766400000)
      ''');
      await db.execute('''
        INSERT INTO transactions (id, amount, category, emoji, date, note, source_recurring_id, created_at)
        VALUES ('old-2', 30000, 'Ăn ngoài', '🍜', '2026-06-07T00:00:00.000', '', NULL, 1759766500000)
      ''');
      await db.execute('''
        INSERT INTO transactions (id, amount, category, emoji, date, note, source_recurring_id, created_at)
        VALUES ('old-3', 1000000, 'Đầu tư', '📈', '2026-06-07T00:00:00.000', 'dau tu', NULL, 1759766600000)
      ''');
      await db.close();

      // Step 3: reopen via DatabaseHelper.database. The file is on disk at
      // v8 and DatabaseHelper opens it at v9 (via testPathOverride), so
      // sqflite invokes DatabaseHelper._onUpgrade(db, oldVersion=8,
      // newVersion=9). This is the REAL production migration path.
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV9 = await dbHelper.database;

      // Column added by the real _onUpgrade?
      final cols = await dbV9.rawQuery('PRAGMA table_info(transactions)');
      final colNames = cols.map((r) => r['name'] as String).toList();
      expect(colNames, contains('search_text_normalized'),
          reason: 'v9 column must exist after real _onUpgrade');

      // Index added by the real _onUpgrade?
      final indexes = await dbV9.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='transactions'");
      final indexNames = indexes.map((r) => r['name'] as String).toList();
      expect(indexNames, contains('idx_transactions_search_text_normalized'),
          reason: 'v9 index must exist after real _onUpgrade');

      // Rows backfilled by the real _onUpgrade (uses
      // buildTransactionSearchText from production normalizer)?
      final backfilled = await dbV9.rawQuery(
          'SELECT id, search_text_normalized FROM transactions ORDER BY id');
      expect(backfilled, hasLength(3));
      for (final row in backfilled) {
        final norm = row['search_text_normalized'] as String;
        expect(norm, isNotEmpty,
            reason: 'id=${row['id']} must have backfilled search_text_normalized');
      }

      // Step 4: verify search works through the real DataSource path
      // (search() normalizes query + LIKE against shadow column).
      final dataSource = SqliteTransactionDataSource(dbHelper);

      final caPhe = await dataSource.search('ca phe');
      expect(caPhe.length, 1, reason: 'ca phe → Cà phê (old-1)');
      expect(caPhe.first.id, 'old-1');

      final anNgoai = await dataSource.search('an ngoai');
      expect(anNgoai.length, 1, reason: 'an ngoai → Ăn ngoài (old-2)');
      expect(anNgoai.first.id, 'old-2');

      final dauTu = await dataSource.search('dau tu');
      expect(dauTu.length, 1, reason: 'dau tu → Đầu tư (old-3)');
      expect(dauTu.first.id, 'old-3');

      // Amount search still works via shadow column
      final amount50000 = await dataSource.search('50000');
      expect(amount50000.any((t) => t.id == 'old-1'), isTrue,
          reason: '50000 should find old-1 via amount in shadow text');

      // Accented query also works (regression: search is symmetric)
      final accented = await dataSource.search('cà phê');
      expect(accented.any((t) => t.id == 'old-1'), isTrue,
          reason: 'cà phê should also match after migration');

      await dbHelper.close();
    });

    test('v8 DB with no transactions — upgrade adds column+index without error',
        () async {
      // Empty v8 DB: just the schema, no rows. The backfill loop in
      // _onUpgrade must handle zero rows gracefully.
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id                  TEXT PRIMARY KEY,
                amount              INTEGER NOT NULL,
                category            TEXT NOT NULL,
                emoji               TEXT NOT NULL DEFAULT '',
                date                TEXT NOT NULL,
                note                TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at          INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
      await db.close();

      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV9 = await dbHelper.database;

      final cols = await dbV9.rawQuery('PRAGMA table_info(transactions)');
      final colNames = cols.map((r) => r['name'] as String).toList();
      expect(colNames, contains('search_text_normalized'),
          reason: 'v9 column must exist after _onUpgrade on empty v8 DB');

      // Backfill loop should run over zero rows; no error.
      final rows = await dbV9.rawQuery('SELECT COUNT(*) AS c FROM transactions');
      expect(rows.first['c'], 0);

      await dbHelper.close();
    });
  });

  group('DB v9 fresh install (real DatabaseHelper)', () {
    test('fresh v9 install includes search_text_normalized column + index',
        () async {
      // No file at dbPath (setUp created the dir but did not create the file)
      // → DatabaseHelper.database triggers _onCreate, not _onUpgrade.
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final db = await dbHelper.database;

      final cols = await db.rawQuery('PRAGMA table_info(transactions)');
      final colNames = cols.map((r) => r['name'] as String).toList();
      expect(colNames, contains('search_text_normalized'),
          reason: 'fresh v9 install must have search_text_normalized in _onCreate');

      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='transactions'");
      final indexNames = indexes.map((r) => r['name'] as String).toList();
      expect(indexNames, contains('idx_transactions_search_text_normalized'),
          reason: 'index must exist');

      await dbHelper.close();
    });
  });
}

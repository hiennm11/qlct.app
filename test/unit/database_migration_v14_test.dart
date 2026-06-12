// ADR-0032: DB v13 → v14 adds carry_amount column to budget_snapshots.
// Exercises the REAL DatabaseHelper._onUpgrade path.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/mappers/budget_snapshot_row_mapper.dart';
import 'package:qlct/models/budget_snapshot.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('v14upgrade_');
    final dbFileName =
        'v14upgrade_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DB migration v13 → v14 (real DatabaseHelper)', () {
    test('v13 DB — after v14 open, carry_amount column exists with default 0', () async {
      // Step 1: create a v13 DB on disk (before carry_amount column)
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 13,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id                       TEXT PRIMARY KEY,
                amount                   INTEGER NOT NULL,
                category                 TEXT NOT NULL,
                category_id              TEXT NOT NULL,
                emoji                    TEXT NOT NULL DEFAULT '',
                date                     TEXT NOT NULL,
                note                     TEXT NOT NULL DEFAULT '',
                source_recurring_id      TEXT,
                created_at               INTEGER NOT NULL,
                search_text_normalized   TEXT NOT NULL DEFAULT ''
              )
            ''');
            await db.execute('''
              CREATE TABLE budgets (
                id              TEXT PRIMARY KEY,
                category_name   TEXT NOT NULL,
                category_id     TEXT NOT NULL,
                monthly_limit   INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE budget_snapshots (
                year_month      TEXT NOT NULL,
                category_name   TEXT NOT NULL,
                category_id     TEXT NOT NULL,
                limit_amount    INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL,
                PRIMARY KEY (year_month, category_id)
              )
            ''');
            await db.execute('''
              CREATE TABLE categories (
                id                       TEXT PRIMARY KEY,
                name                     TEXT NOT NULL,
                normalized_name          TEXT NOT NULL UNIQUE,
                emoji                    TEXT NOT NULL,
                kind                     TEXT NOT NULL,
                budget_behavior          TEXT NOT NULL,
                quick_amount_min         INTEGER NOT NULL,
                quick_amount_default     INTEGER NOT NULL,
                quick_amount_max         INTEGER NOT NULL,
                voice_phrases_json       TEXT NOT NULL,
                sort_order              INTEGER NOT NULL,
                is_system INTEGER NOT NULL DEFAULT 0,
                is_archived              INTEGER NOT NULL DEFAULT 0,
                created_at               INTEGER NOT NULL,
                updated_at               INTEGER NOT NULL
              )
            ''');
          },
        ),
      );

      // Insert a snapshot row (pre-v14)
      await db.insert('budget_snapshots', {
        'year_month': '2026-05',
        'category_name': 'Ăn ngoài',
        'category_id': 'food_out',
        'limit_amount': 1000000,
        'alert_threshold': 80,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.close();

      // Step 2: open with DatabaseHelper — should trigger v13→v14 migration
      final helper = DatabaseHelper();
      helper.testPathOverride = dbPath;
      final openedDb = await helper.database;

      // Step 3: verify carry_amount column exists
      final result = await openedDb.rawQuery(
          'SELECT carry_amount FROM budget_snapshots LIMIT 1');
      expect(result.length, 1);
      expect(result.first['carry_amount'], 0,
          reason: 'carry_amount should default to 0 on existing rows');

      // Step 4: verify new rows can be inserted with explicit carry_amount
      await openedDb.insert('budget_snapshots', {
        'year_month': '2026-06',
        'category_name': 'Cà phê',
        'category_id': 'ca_phe',
        'limit_amount': 500000,
        'alert_threshold': 80,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'carry_amount': 300000,
      });

      final rows = await openedDb.rawQuery(
          "SELECT * FROM budget_snapshots WHERE year_month = '2026-06'");
      expect(rows.length, 1);
      expect(rows.first['carry_amount'], 300000);

      await helper.close();
    });

    test('v13 DB — new table create includes carry_amount', () async {
      // Verify the CREATE TABLE statement in _onCreate includes carry_amount
      // by creating a fresh v14 DB and checking the schema
      final helper = DatabaseHelper();
      helper.testPathOverride = dbPath;
      final db = await helper.database;

      final schema = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='budget_snapshots'");
      expect(schema.length, 1);
      expect(schema.first['sql'].toString().contains('carry_amount'), isTrue,
          reason: 'CREATE TABLE budget_snapshots must include carry_amount');

      await helper.close();
    });
  });
}

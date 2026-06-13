// ADR-0037: DB v14 → v15 adds `deleted_at` column to categories for
// soft-delete trash, plus a partial index on `deleted_at IS NULL` for
// cheap active-only lookups. Exercises the REAL DatabaseHelper._onUpgrade
// path.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/mappers/category_row_mapper.dart';
import 'package:qlct/models/category.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('v15upgrade_');
    final dbFileName =
        'v15upgrade_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DB migration v14 → v15 (real DatabaseHelper)', () {
    test('v14 DB — after v15 open, deleted_at column exists with NULL default',
        () async {
      // Step 1: create a v14 DB on disk (no deleted_at column).
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 14,
          onCreate: (db, version) async {
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
                is_system                INTEGER NOT NULL DEFAULT 0,
                is_archived              INTEGER NOT NULL DEFAULT 0,
                created_at               INTEGER NOT NULL,
                updated_at               INTEGER NOT NULL
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_categories_normalized_name ON categories(normalized_name)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_categories_is_archived ON categories(is_archived)');
          },
        ),
      );

      // Insert a v14-era category row (pre-soft-delete).
      await db.insert('categories', {
        'id': 'food_out',
        'name': 'Ăn ngoài',
        'normalized_name': 'an ngoai',
        'emoji': '🍜',
        'kind': 'spending',
        'budget_behavior': 'flexible',
        'quick_amount_min': 30000,
        'quick_amount_default': 50000,
        'quick_amount_max': 200000,
        'voice_phrases_json': '[]',
        'sort_order': 10,
        'is_system': 0,
        'is_archived': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.close();

      // Step 2: open with DatabaseHelper — should trigger v14→v15 migration.
      final helper = DatabaseHelper();
      helper.testPathOverride = dbPath;
      final openedDb = await helper.database;

      // Step 3: verify deleted_at column exists and is NULL on existing rows.
      final result = await openedDb.rawQuery(
          'SELECT id, deleted_at FROM categories WHERE id = ?', ['food_out']);
      expect(result.length, 1, reason: 'v14 row should survive migration');
      expect(result.first['deleted_at'], isNull,
          reason: 'deleted_at should default to NULL on existing rows');

      // Step 4: verify the partial index on deleted_at was created.
      final indexes = await openedDb.rawQuery(
          "SELECT name, sql FROM sqlite_master "
          "WHERE type='index' AND tbl_name='categories'");
      final hasPartial = indexes.any((row) {
        final sql = row['sql']?.toString() ?? '';
        return sql.contains('deleted_at') && sql.contains('IS NULL');
      });
      expect(hasPartial, isTrue,
          reason:
              'partial index `idx_categories_deleted_at ... WHERE deleted_at IS NULL` must exist');

      await helper.close();
    });

    test('v15 DB — fresh install includes deleted_at column + partial index',
        () async {
      // Verify the CREATE TABLE + index in _onCreate are correct.
      final helper = DatabaseHelper();
      helper.testPathOverride = dbPath;
      final db = await helper.database;

      // deleted_at must appear in the CREATE TABLE statement.
      final schema = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='categories'");
      expect(schema.length, 1);
      expect(schema.first['sql'].toString().contains('deleted_at'), isTrue,
          reason: 'CREATE TABLE categories must include deleted_at');

      // Partial index must be present.
      final indexes = await db.rawQuery(
          "SELECT name, sql FROM sqlite_master "
          "WHERE type='index' AND tbl_name='categories'");
      final hasPartial = indexes.any((row) {
        final sql = row['sql']?.toString() ?? '';
        return sql.contains('deleted_at') && sql.contains('IS NULL');
      });
      expect(hasPartial, isTrue,
          reason: 'partial index on deleted_at IS NULL must exist');

      await helper.close();
    });

    test('v15 DB — mapper round-trip preserves deletedAt = null + non-null',
        () async {
      final helper = DatabaseHelper();
      helper.testPathOverride = dbPath;
      final db = await helper.database;

      final now = DateTime(2026, 6, 13, 12, 0, 0);

      // Active row.
      final active = Category(
        id: 'cat_active',
        name: 'Cà phê',
        normalizedName: 'ca phe',
        emoji: '☕',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 10000,
        quickAmountDefault: 20000,
        quickAmountMax: 100000,
        voicePhrases: const [],
        sortOrder: 10,
        isSystem: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('categories', categoryToRow(active));

      // Soft-deleted row (must have a distinct normalizedName to avoid the
      // UNIQUE constraint on categories.normalized_name).
      final trashed = active.copyWith(
        id: 'cat_trashed',
        name: 'Cà phê đã xoá',
        normalizedName: 'ca phe da xoa',
        deletedAt: now.add(const Duration(days: 3)),
      );
      await db.insert('categories', categoryToRow(trashed));

      // Read back, mapper must reconstruct deletedAt.
      final activeMap = (await db.query('categories', where: 'id = ?', whereArgs: ['cat_active'])).first;
      final activeRead = categoryFromRow(activeMap);
      expect(activeRead.deletedAt, isNull);

      final trashedMap = (await db.query('categories', where: 'id = ?', whereArgs: ['cat_trashed'])).first;
      final trashedRead = categoryFromRow(trashedMap);
      expect(trashedRead.deletedAt, isNotNull);
      expect(trashedRead.deletedAt!.millisecondsSinceEpoch,
          trashed.deletedAt!.millisecondsSinceEpoch);

      await helper.close();
    });
  });
}

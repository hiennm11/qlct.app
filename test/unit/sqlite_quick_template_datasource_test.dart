import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_quick_template_datasource.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SqliteQuickTemplateDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE quick_templates (
              id              TEXT PRIMARY KEY,
              title           TEXT NOT NULL,
              amount          INTEGER NOT NULL,
              category_name   TEXT NOT NULL,
              category_id     TEXT NOT NULL DEFAULT '',
              note            TEXT NOT NULL DEFAULT '',
              emoji           TEXT NOT NULL,
              is_pinned       INTEGER NOT NULL DEFAULT 0,
              usage_count     INTEGER NOT NULL DEFAULT 0,
              last_used_at    TEXT,
              created_at      TEXT NOT NULL,
              updated_at      TEXT NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_quick_templates_pinned ON quick_templates(is_pinned)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_quick_templates_usage ON quick_templates(usage_count DESC, last_used_at DESC)');
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteQuickTemplateDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  QuickTemplate makeTemplate({
    String id = 't-1',
    String title = 'Cơm trưa',
    int amount = 35000,
    String categoryName = 'Ăn ngoài',
    String categoryId = 'food_out',
    String note = '',
    String emoji = '🍜',
    bool isPinned = false,
    int usageCount = 0,
    DateTime? lastUsedAt,
  }) {
    final now = DateTime(2026, 6, 7, 10);
    return QuickTemplate(
      id: id,
      title: title,
      amount: amount,
      categoryName: categoryName,
      categoryId: categoryId,
      note: note,
      emoji: emoji,
      isPinned: isPinned,
      usageCount: usageCount,
      lastUsedAt: lastUsedAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('insert + getAll', () {
    test('inserts and retrieves a template', () async {
      final t = makeTemplate();
      await dataSource.insert(t);
      final all = await dataSource.getAll();
      expect(all.length, 1);
      expect(all.first.id, 't-1');
      expect(all.first.title, 'Cơm trưa');
      expect(all.first.amount, 35000);
    });

    test('getAll returns empty list when empty', () async {
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });

  group('getTopTemplates', () {
    test('returns up to limit templates', () async {
      for (int i = 0; i < 10; i++) {
        await dataSource.insert(makeTemplate(id: 't-$i', title: 'T$i'));
      }
      final top = await dataSource.getTopTemplates(limit: 3);
      expect(top.length, 3);
    });

    test('defaults limit to 8', () async {
      for (int i = 0; i < 12; i++) {
        await dataSource.insert(makeTemplate(id: 't-$i', title: 'T$i'));
      }
      final top = await dataSource.getTopTemplates();
      expect(top.length, 8);
    });

    test('pinned templates appear first', () async {
      await dataSource.insert(makeTemplate(id: 't-1', title: 'Unpinned'));
      await dataSource.insert(makeTemplate(id: 't-2', title: 'Pinned', isPinned: true));
      await dataSource.insert(makeTemplate(id: 't-3', title: 'Also pinned', isPinned: true));

      final top = await dataSource.getTopTemplates(limit: 8);
      expect(top.first.id, 't-2');
      expect(top[1].id, 't-3');
      expect(top[2].id, 't-1');
    });

    test('sorts by usageCount DESC among same pinned status', () async {
      await dataSource.insert(makeTemplate(id: 't-1', title: 'Low', usageCount: 2));
      await dataSource.insert(makeTemplate(id: 't-2', title: 'High', usageCount: 10));
      await dataSource.insert(makeTemplate(id: 't-3', title: 'Med', usageCount: 5));

      final top = await dataSource.getTopTemplates(limit: 8);
      expect(top[0].id, 't-2');
      expect(top[1].id, 't-3');
      expect(top[2].id, 't-1');
    });
  });

  group('getById', () {
    test('returns template when found', () async {
      await dataSource.insert(makeTemplate(id: 't-1'));
      final found = await dataSource.getById('t-1');
      expect(found, isNotNull);
      expect(found!.id, 't-1');
    });

    test('returns null when not found', () async {
      final found = await dataSource.getById('nonexistent');
      expect(found, isNull);
    });
  });

  group('existsExactDuplicate', () {
    test('returns true for exact match', () async {
      await dataSource.insert(makeTemplate(
        id: 't-1',
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: 'trưa',
      ));

      final exists = await dataSource.existsExactDuplicate(
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: 'trưa',
      );

      expect(exists, isTrue);
    });

    test('returns false when different amount', () async {
      await dataSource.insert(makeTemplate(
        id: 't-1',
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
      ));

      final exists = await dataSource.existsExactDuplicate(
        title: 'Cơm trưa',
        amount: 40000,
        categoryName: 'Ăn ngoài',
        note: '',
      );

      expect(exists, isFalse);
    });

    test('case-insensitive title/note comparison', () async {
      await dataSource.insert(makeTemplate(
        id: 't-1',
        title: 'Cơm Trưa',
        categoryName: 'Ăn ngoài',
        note: 'Trưa Nhanh',
      ));

      final exists = await dataSource.existsExactDuplicate(
        title: 'cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: 'trưa nhanh',
      );

      expect(exists, isTrue);
    });

    test('trim removes whitespace for comparison', () async {
      await dataSource.insert(makeTemplate(
        id: 't-1',
        title: '  Cơm trưa  ',
        note: '  trưa  ',
      ));

      final exists = await dataSource.existsExactDuplicate(
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: 'trưa',
      );

      expect(exists, isTrue);
    });

    test('excludeId skips matching row during update', () async {
      await dataSource.insert(makeTemplate(
        id: 't-1',
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
      ));

      final exists = await dataSource.existsExactDuplicate(
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: '',
        excludeId: 't-1',
      );

      expect(exists, isFalse);
    });

    test('returns false when no templates exist', () async {
      final exists = await dataSource.existsExactDuplicate(
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: '',
      );
      expect(exists, isFalse);
    });
  });

  group('update', () {
    test('updates existing template', () async {
      await dataSource.insert(makeTemplate(id: 't-1'));
      final updated = makeTemplate(id: 't-1', title: 'Updated');
      await dataSource.update(updated);

      final found = await dataSource.getById('t-1');
      expect(found!.title, 'Updated');
    });
  });

  group('delete', () {
    test('removes template by id', () async {
      await dataSource.insert(makeTemplate(id: 't-1'));
      await dataSource.insert(makeTemplate(id: 't-2'));
      await dataSource.delete('t-1');

      final all = await dataSource.getAll();
      expect(all.length, 1);
      expect(all.first.id, 't-2');
    });
  });

  group('markUsed', () {
    test('increments usageCount and sets lastUsedAt', () async {
      await dataSource.insert(makeTemplate(id: 't-1', usageCount: 5));
      final usedAt = DateTime(2026, 6, 7, 14);
      await dataSource.markUsed('t-1', usedAt);

      final found = await dataSource.getById('t-1');
      expect(found!.usageCount, 6);
      expect(found.lastUsedAt, usedAt);
    });

    test('lastUsedAt can be null initially and still markUsed works', () async {
      await dataSource.insert(makeTemplate(id: 't-1', usageCount: 0, lastUsedAt: null));
      await dataSource.markUsed('t-1', DateTime(2026, 6, 7));

      final found = await dataSource.getById('t-1');
      expect(found!.usageCount, 1);
      expect(found.lastUsedAt, isNotNull);
    });
  });

  group('insertMany', () {
    test('bulk inserts multiple templates', () async {
      final templates = [
        makeTemplate(id: 't-1', title: 'A'),
        makeTemplate(id: 't-2', title: 'B'),
        makeTemplate(id: 't-3', title: 'C'),
      ];
      await dataSource.insertMany(templates);

      final all = await dataSource.getAll();
      expect(all.length, 3);
    });

    test('handles empty list', () async {
      await dataSource.insertMany([]);
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });

  group('clearAll', () {
    test('deletes all templates', () async {
      await dataSource.insert(makeTemplate(id: 't-1'));
      await dataSource.insert(makeTemplate(id: 't-2'));
      await dataSource.clearAll();

      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });

  group('count', () {
    // ADR-0023 §8: count uses SQL COUNT(*) not getAll().length
    test('returns 0 when no templates', () async {
      final result = await dataSource.count();
      expect(result, 0);
    });

    test('returns correct count after inserting templates', () async {
      await dataSource.insert(makeTemplate(id: 'count-qt-1', title: 'A'));
      await dataSource.insert(makeTemplate(id: 'count-qt-2', title: 'B'));
      await dataSource.insert(makeTemplate(id: 'count-qt-3', title: 'C'));

      final result = await dataSource.count();
      expect(result, 3);
    });

    test('returns correct count after deleting a template', () async {
      await dataSource.insert(makeTemplate(id: 'count-del-qt-1'));
      await dataSource.insert(makeTemplate(id: 'count-del-qt-2'));

      await dataSource.delete('count-del-qt-1');

      final result = await dataSource.count();
      expect(result, 1);
    });

    test('returns 0 after clearAll', () async {
      await dataSource.insert(makeTemplate(id: 'count-clear-qt-1'));
      await dataSource.insert(makeTemplate(id: 'count-clear-qt-2'));

      await dataSource.clearAll();

      final result = await dataSource.count();
      expect(result, 0);
    });
  });
}
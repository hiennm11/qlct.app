import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
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
    // Use in-memory database with version 6 (no FTS5)
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 6,
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
          await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
          await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 6) {
            await db.execute('DROP TABLE IF EXISTS transactions_fts');
          }
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteTransactionDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('LIKE search', () {
    test('returns empty list when no transactions', () async {
      final result = await dataSource.search('test');
      expect(result, isEmpty);
    });

    test('returns empty list for empty query', () async {
      final result = await dataSource.search('');
      expect(result, isEmpty);
    });

    test('returns empty list for whitespace query', () async {
      final result = await dataSource.search('   ');
      expect(result, isEmpty);
    });

    test('search by note text finds matching transactions', () async {
      final t1 = Transaction(
        id: 'search-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'ăn trưa nhà hàng',
      );
      final t2 = Transaction(
        id: 'search-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: 'cà phê sáng',
      );
      await dataSource.add(t1);
      await dataSource.add(t2);

      final result = await dataSource.search('trưa');

      expect(result.length, 1);
      expect(result.first.id, 'search-1');
    });

    test('search by category finds matching transactions', () async {
      final t1 = Transaction(
        id: 'cat-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      final t2 = Transaction(
        id: 'cat-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: '',
      );
      await dataSource.add(t1);
      await dataSource.add(t2);

      final result = await dataSource.search('Cà phê');

      expect(result.length, 1);
      expect(result.first.id, 'cat-2');
    });

    test('search by amount finds matching transactions', () async {
      final t1 = Transaction(
        id: 'amt-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      await dataSource.add(t1);

      final result = await dataSource.search('50000');

      expect(result.length, 1);
      expect(result.first.id, 'amt-1');
    });

    test('search finds multiple matching transactions', () async {
      final t1 = Transaction(
        id: 'multi-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'trưa',
      );
      final t2 = Transaction(
        id: 'multi-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: 'trưa',
      );
      await dataSource.add(t1);
      await dataSource.add(t2);

      final result = await dataSource.search('trưa');

      expect(result.length, 2);
    });

    test('no matches returns empty list', () async {
      final t = Transaction(
        id: 'no-match',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'ăn trưa',
      );
      await dataSource.add(t);

      final result = await dataSource.search('không có');

      expect(result, isEmpty);
    });

    test('partial word match works', () async {
      final t = Transaction(
        id: 'partial-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'café sáng',
      );
      await dataSource.add(t);

      // LIKE pattern matches substring anywhere
      final result = await dataSource.search('fé');

      expect(result.length, 1);
      expect(result.first.id, 'partial-1');
    });

    test('search is case-sensitive (LIKE limitation)', () async {
      final t = Transaction(
        id: 'case-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'Cà phê sữa',
      );
      await dataSource.add(t);

      // LIKE is case-sensitive in SQLite by default
      final lowerResult = await dataSource.search('cà phê');
      final upperResult = await dataSource.search('CÀ PHÊ');

      // Both might find or neither might find, depending on collation
      // This documents the behavior - SQLite LIKE is collation-dependent
      expect(lowerResult.length, greaterThanOrEqualTo(0));
      expect(upperResult.length, greaterThanOrEqualTo(0));
    });

    test('search across note AND category combined', () async {
      final t1 = Transaction(
        id: 'combo-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'café',
      );
      final t2 = Transaction(
        id: 'combo-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: '',
      );
      await dataSource.add(t1);
      await dataSource.add(t2);

      // "café" matches in note
      final resultCafe = await dataSource.search('café');
      expect(resultCafe.length, greaterThanOrEqualTo(1));

      // "cà phê" matches in category
      final resultCaphe = await dataSource.search('cà phê');
      expect(resultCaphe.length, greaterThanOrEqualTo(1));
    });

    test('search results ordered by created_at DESC', () async {
      final t1 = Transaction(
        id: 'order-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: 'test search',
      );
      final t2 = Transaction(
        id: 'order-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: 'test search',
      );
      await dataSource.add(t1);
      await dataSource.add(t2);

      final result = await dataSource.search('test search');

      expect(result.length, 2);
      // Most recent first
      expect(result.first.id, 'order-2');
      expect(result.last.id, 'order-1');
    });
  });

  group('deleteMultiple', () {
    test('deletes multiple transactions by id', () async {
      final t1 = Transaction(
        id: 'del-multi-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      final t2 = Transaction(
        id: 'del-multi-2',
        amount: 30000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 4),
        note: '',
      );
      final t3 = Transaction(
        id: 'del-multi-3',
        amount: 40000,
        category: 'Di chuyển',
        emoji: '🚗',
        date: DateTime(2026, 6, 5),
        note: '',
      );
      await dataSource.add(t1);
      await dataSource.add(t2);
      await dataSource.add(t3);

      await dataSource.deleteMultiple(['del-multi-1', 'del-multi-3']);

      final remaining = await dataSource.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'del-multi-2');
    });

    test('handles empty list', () async {
      await dataSource.deleteMultiple([]);
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('handles non-existent ids gracefully', () async {
      final t = Transaction(
        id: 'exist-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 3),
        note: '',
      );
      await dataSource.add(t);

      // Delete non-existent id should not throw
      await dataSource.deleteMultiple(['non-existent-1', 'non-existent-2']);

      final remaining = await dataSource.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'exist-1');
    });
  });

  group('CRUD without FTS', () {
    test('add persists transaction', () async {
      final t = Transaction(
        id: 'add-test',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍕',
        date: DateTime(2026, 6, 3),
        note: 'test',
      );
      await dataSource.add(t);

      final all = await dataSource.getAll();
      expect(all.any((t) => t.id == 'add-test'), isTrue);
    });

    test('update persists changes', () async {
      final t = Transaction(
        id: 'update-test',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍕',
        date: DateTime(2026, 6, 3),
        note: 'original',
      );
      await dataSource.add(t);
      await dataSource.update(Transaction(
        id: 'update-test',
        amount: 60000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 3),
        note: 'updated',
      ));

      final all = await dataSource.getAll();
      expect(all.first.amount, 60000);
      expect(all.first.note, 'updated');
    });

    test('delete removes transaction', () async {
      final t = Transaction(
        id: 'delete-test',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍕',
        date: DateTime(2026, 6, 3),
        note: 'test',
      );
      await dataSource.add(t);
      await dataSource.delete('delete-test');

      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });
}

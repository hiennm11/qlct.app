// ADR-0022: normalized Vietnamese search via shadow column.
// Search queries are normalized and matched against search_text_normalized.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_transaction_datasource.dart';
import 'package:qlct/models/transaction.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SqliteTransactionDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    // Use v9 schema (includes search_text_normalized column)
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE transactions (
              id                       TEXT PRIMARY KEY,
              amount                   INTEGER NOT NULL,
              category                 TEXT NOT NULL,
              category_id              TEXT NOT NULL DEFAULT '',
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
          await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteTransactionDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('normalized search via shadow column', () {
    test('search ca phe matches Cà phê category', () async {
      final t = _makeTx(id: 's-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      await dataSource.add(t);

      final result = await dataSource.search('ca phe');

      expect(result.length, 1);
      expect(result.first.id, 's-1');
    });

    test('search cà phê also matches Cà phê category', () async {
      final t = _makeTx(id: 's-2', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      await dataSource.add(t);

      final result = await dataSource.search('cà phê');

      expect(result.length, 1);
      expect(result.first.id, 's-2');
    });

    test('search an ngoai matches Ăn ngoài category', () async {
      final t = _makeTx(id: 's-3', category: 'Ăn ngoài', categoryId: 'food_out', amount: 50000);
      await dataSource.add(t);

      final result = await dataSource.search('an ngoai');

      expect(result.length, 1);
      expect(result.first.id, 's-3');
    });

    test('search dau tu matches Đầu tư category', () async {
      final t = _makeTx(id: 's-4', category: 'Đầu tư', categoryId: 'investment', amount: 1000000);
      await dataSource.add(t);

      final result = await dataSource.search('dau tu');

      expect(result.length, 1);
      expect(result.first.id, 's-4');
    });

    test('search note without accents matches accented note', () async {
      final t = _makeTx(id: 's-5', category: 'Khác', categoryId: 'other', amount: 10000, note: 'Cà phê sáng');
      await dataSource.add(t);

      final result = await dataSource.search('ca phe sang');

      expect(result.length, 1);
      expect(result.first.id, 's-5');
    });

    test('search amount text matches amount', () async {
      final t = _makeTx(id: 's-6', category: 'Mua sắm', categoryId: 'online_shopping', amount: 150000);
      await dataSource.add(t);

      final result = await dataSource.search('150000');

      expect(result.length, 1);
      expect(result.first.id, 's-6');
    });

    test('search across multiple transactions', () async {
      final t1 = _makeTx(id: 'm-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      final t2 = _makeTx(id: 'm-2', category: 'Ăn ngoài', categoryId: 'food_out', amount: 50000);
      final t3 = _makeTx(id: 'm-3', category: 'Mua sắm', categoryId: 'online_shopping', amount: 200000);
      await dataSource.bulkInsert([t1, t2, t3]);

      final result = await dataSource.search('ngoai');

      expect(result.length, 1);
      expect(result.first.id, 'm-2');
    });

    test('update note/category/amount updates searchable normalized text', () async {
      final original = _makeTx(id: 'u-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000, note: 'original');
      await dataSource.add(original);

      // Search with old values — should find
      expect((await dataSource.search('ca phe')).length, 1);

      // Update category to Đầu tư and amount
      final updated = Transaction(
        id: 'u-1',
        amount: 500000,
        category: 'Đầu tư', categoryId: 'investment',
        emoji: '📈',
        date: DateTime(2026, 6, 7),
        note: 'dau tu chung khoan',
      );
      await dataSource.update(updated);

      // Old category no longer searchable
      final oldSearch = await dataSource.search('ca phe');
      expect(oldSearch.any((t) => t.id == 'u-1'), isFalse,
          reason: 'updated row should not match old category');

      // New category searchable
      final newSearch = await dataSource.search('dau tu');
      expect(newSearch.any((t) => t.id == 'u-1'), isTrue,
          reason: 'updated row should match new category');
    });

    test('bulkInsert populates normalized shadow text', () async {
      final t1 = _makeTx(id: 'b-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      final t2 = _makeTx(id: 'b-2', category: 'Ăn ngoài', categoryId: 'food_out', amount: 50000);
      await dataSource.bulkInsert([t1, t2]);

      final caPhe = await dataSource.search('ca phe');
      expect(caPhe.any((t) => t.id == 'b-1'), isTrue,
          reason: 'bulkInsert should populate normalized text');

      final anNgoai = await dataSource.search('an ngoai');
      expect(anNgoai.any((t) => t.id == 'b-2'), isTrue);
    });

    test('empty query returns empty list', () async {
      final t = _makeTx(id: 'e-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      await dataSource.add(t);

      expect(await dataSource.search(''), isEmpty);
      expect(await dataSource.search('   '), isEmpty);
    });

    test('no match returns empty list', () async {
      final t = _makeTx(id: 'n-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      await dataSource.add(t);

      expect(await dataSource.search('khong co'), isEmpty);
    });

    test('search results ordered by created_at DESC', () async {
      await dataSource.add(_makeTx(id: 'o-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000));
      await Future.delayed(const Duration(milliseconds: 10));
      await dataSource.add(_makeTx(id: 'o-2', category: 'Cà phê', categoryId: 'coffee', amount: 40000));

      final result = await dataSource.search('ca phe');

      expect(result.length, 2);
      expect(result.first.id, 'o-2', reason: 'most recently added first');
      expect(result.last.id, 'o-1');
    });

    test('uppercase query lowercased and matched', () async {
      final t = _makeTx(id: 'uc-1', category: 'Cà phê', categoryId: 'coffee', amount: 30000);
      await dataSource.add(t);

      final result = await dataSource.search('CA PHE');

      expect(result.length, 1);
      expect(result.first.id, 'uc-1');
    });
  });
}

Transaction _makeTx({
  required String id,
  required String category,
  required String categoryId,
  required int amount,
  String note = '',
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    categoryId: categoryId,
    emoji: '🍜',
    date: DateTime(2026, 6, 7),
    note: note,
  );
}
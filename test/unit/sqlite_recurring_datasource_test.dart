import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide RecurringTransaction;
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_recurring_datasource.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SqliteRecurringDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE recurring_transactions (
              id            TEXT PRIMARY KEY,
              category_name TEXT NOT NULL,
              amount        INTEGER NOT NULL,
              note          TEXT NOT NULL DEFAULT '',
              frequency     TEXT NOT NULL,
              next_run_at   TEXT NOT NULL,
              is_active     INTEGER NOT NULL DEFAULT 1,
              created_at    TEXT NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE recurring_transactions (
                id            TEXT PRIMARY KEY,
                category_name TEXT NOT NULL,
                amount        INTEGER NOT NULL,
                note          TEXT NOT NULL DEFAULT '',
                frequency     TEXT NOT NULL,
                next_run_at   TEXT NOT NULL,
                is_active     INTEGER NOT NULL DEFAULT 1,
                created_at    TEXT NOT NULL
              )
            ''');
            await db.execute(
                'CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at)');
          }
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteRecurringDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('getAll', () {
    test('returns empty list when no recurring transactions exist', () async {
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('returns all recurring transactions sorted by created_at DESC',
        () async {
      final rt1 = RecurringTransaction(
        id: 'uuid-1',
        categoryName: 'Ăn ngoài',
        amount: 50000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
      );
      final rt2 = RecurringTransaction(
        id: 'uuid-2',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'weekly',
        nextRunAt: DateTime(2026, 6, 2),
        createdAt: DateTime(2026, 6, 2),
      );

      await dataSource.insert(rt1);
      await Future.delayed(const Duration(milliseconds: 10));
      await dataSource.insert(rt2);

      final result = await dataSource.getAll();

      expect(result.length, 2);
      expect(result[0].id, 'uuid-2');
      expect(result[1].id, 'uuid-1');
    });
  });

  group('insert', () {
    test('creates new recurring transaction', () async {
      final rt = RecurringTransaction(
        id: 'new-uuid',
        categoryName: 'Cà phê',
        amount: 20000,
        note: 'Every morning',
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 4),
      );

      await dataSource.insert(rt);

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, 'new-uuid');
      expect(result.first.categoryName, 'Cà phê');
      expect(result.first.amount, 20000);
      expect(result.first.note, 'Every morning');
      expect(result.first.frequency, 'daily');
      expect(result.first.isActive, true);
    });
  });

  group('getActiveDue', () {
    test('returns only active rules with nextRunAt <= now', () async {
      final pastDue = RecurringTransaction(
        id: 'due-1',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final future = RecurringTransaction(
        id: 'due-2',
        categoryName: 'Ăn ngoài',
        amount: 50000,
        nextRunAt: DateTime(2027, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final inactive = RecurringTransaction(
        id: 'due-3',
        categoryName: 'Giải trí',
        amount: 30000,
        nextRunAt: DateTime(2026, 1, 1),
        isActive: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await dataSource.insert(pastDue);
      await dataSource.insert(future);
      await dataSource.insert(inactive);

      final result = await dataSource.getActiveDue(DateTime(2026, 12, 31));

      expect(result.length, 1);
      expect(result.first.id, 'due-1');
    });

    test('returns empty list when no rules due', () async {
      final future = RecurringTransaction(
        id: 'future-1',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2027, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 6, 4),
      );
      await dataSource.insert(future);

      final result = await dataSource.getActiveDue(DateTime(2026, 6, 4));

      expect(result, isEmpty);
    });
  });

  group('updateNextRunAt', () {
    test('updates next_run_at for existing recurring transaction', () async {
      final rt = RecurringTransaction(
        id: 'update-1',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      await dataSource.insert(rt);

      await dataSource.updateNextRunAt('update-1', DateTime(2026, 6, 5));

      final result = await dataSource.getAll();
      expect(result.first.nextRunAt, DateTime(2026, 6, 5));
    });
  });

  group('update', () {
    test('updates existing recurring transaction', () async {
      final original = RecurringTransaction(
        id: 'update-test',
        categoryName: 'Cà phê',
        amount: 20000,
        note: 'original note',
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      await dataSource.insert(original);

      final updated = original.copyWith(
        amount: 30000,
        note: 'updated note',
        isActive: false,
      );
      await dataSource.update(updated);

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.amount, 30000);
      expect(result.first.note, 'updated note');
      expect(result.first.isActive, false);
      expect(result.first.categoryName, 'Cà phê');
    });
  });

  group('delete', () {
    test('removes recurring transaction by id', () async {
      final rt1 = RecurringTransaction(
        id: 'delete-1',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
      );
      final rt2 = RecurringTransaction(
        id: 'delete-2',
        categoryName: 'Ăn ngoài',
        amount: 50000,
        nextRunAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
      );
      await dataSource.insert(rt1);
      await dataSource.insert(rt2);

      await dataSource.delete('delete-1');

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, 'delete-2');
    });

    test('does nothing when deleting non-existent id', () async {
      final rt = RecurringTransaction(
        id: 'existing',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
      );
      await dataSource.insert(rt);

      await dataSource.delete('non-existent');

      final result = await dataSource.getAll();
      expect(result.length, 1);
    });
  });
}
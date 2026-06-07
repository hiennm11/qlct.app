import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/sqlite_recurring_datasource.dart';
import 'package:qlct/data/datasources/sqlite_transaction_datasource.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/services/export_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late SqliteRecurringDataSource recurringDs;
  late SqliteTransactionDataSource transactionDs;
  late SqliteRecurringDataSource recurringRepo;
  late SqliteTransactionDataSource transactionRepo;
  late RecurringTransactionViewModel recurringVm;
  late ExpenseViewModel expenseVm;

  // Create both tables in an in-memory SQLite database
  Future<Database> createDb() async {
    return await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
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
              'CREATE INDEX idx_transactions_source ON transactions(source_recurring_id)');
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
      ),
    );
  }

  setUp(() async {
    final db = await createDb();
    dbHelper = DatabaseHelper();
    dbHelper.testDatabase = db;

    recurringDs = SqliteRecurringDataSource(dbHelper);
    transactionDs = SqliteTransactionDataSource(dbHelper);

    recurringDs = SqliteRecurringDataSource(dbHelper);
    transactionDs = SqliteTransactionDataSource(dbHelper);

    recurringVm =
        RecurringTransactionViewModel(recurringDs, transactionDs);
    expenseVm = ExpenseViewModel(
      transactionDs,
      ExportService(),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Recurring generation - end-to-end', () {
    test('Create recurring rule → generate → transaction appears in repo',
        () async {
      // Add recurring rule with nextRunAt in the past
      await recurringVm.addRecurring(
        categoryName: 'Cà phê',
        amount: 20000,
        note: 'morning coffee',
        frequency: 'daily',
        startDate: DateTime(2026, 6, 1),
      );

      // Verify rule exists
      final rules = await recurringDs.getAll();
      expect(rules.length, 1);
      expect(rules.first.categoryName, 'Cà phê');
      expect(rules.first.amount, 20000);
      expect(rules.first.frequency, 'daily');
      expect(rules.first.isActive, true);

      // Trigger generation
      await recurringVm.checkAndGenerate();

      // Verify transaction was created
      final transactions = await transactionDs.getAll();
      expect(transactions.length, 1);
      expect(transactions.first.amount, 20000);
      expect(transactions.first.category, 'Cà phê');
      expect(transactions.first.note, 'morning coffee');
      expect(transactions.first.sourceRecurringId, rules.first.id);

      // Verify nextRunAt advanced
      final updatedRules = await recurringDs.getAll();
      expect(
        updatedRules.first.nextRunAt.isAfter(DateTime(2026, 6, 1)),
        true,
      );
    });

    test('Generate twice → no duplicate (sourceRecurringId + date check)',
        () async {
      // Add rule with past date
      await recurringVm.addRecurring(
        categoryName: 'Ăn ngoài',
        amount: 50000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 1),
      );

      // Generate first time
      await recurringVm.checkAndGenerate();

      // Generate second time
      await recurringVm.checkAndGenerate();

      // Should still have only 1 transaction
      final transactions = await transactionDs.getAll();
      expect(transactions.length, 1);
    });

    test('Multiple active rules → all generate correctly', () async {
      await recurringVm.addRecurring(
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 1),
      );
      await recurringVm.addRecurring(
        categoryName: 'Ăn ngoài',
        amount: 50000,
        frequency: 'weekly',
        startDate: DateTime(2026, 6, 1),
      );
      await recurringVm.addRecurring(
        categoryName: 'Subscription',
        amount: 200000,
        frequency: 'monthly',
        startDate: DateTime(2026, 6, 1),
      );

      await recurringVm.checkAndGenerate();

      final transactions = await transactionDs.getAll();
      expect(transactions.length, 3);

      final amounts = transactions.map((t) => t.amount).toSet();
      expect(amounts, {20000, 50000, 200000});
    });

    test('Inactive rule → does NOT generate', () async {
      // Insert inactive rule directly
      final inactiveRule = RecurringTransaction(
        id: 'inactive-rule',
        categoryName: 'Giải trí',
        amount: 30000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: false,
        createdAt: DateTime(2026, 6, 1),
      );
      await recurringDs.insert(inactiveRule);

      // Generate
      await recurringVm.checkAndGenerate();

      // No transaction created
      final transactions = await transactionDs.getAll();
      expect(transactions, isEmpty);
    });

    test('Catch-up: nextRunAt in past → generates 1 transaction, nextRunAt advances',
        () async {
      // Rule was missed for 5 days
      final missedRule = RecurringTransaction(
        id: 'missed-rule',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1), // 5 days ago
        isActive: true,
        createdAt: DateTime(2026, 5, 1),
      );
      await recurringDs.insert(missedRule);

      // Generate on 2026-06-06
      await recurringVm.checkAndGenerate();

      // Only 1 transaction (not 5) - generates once per checkAndGenerate call
      final transactions = await transactionDs.getAll();
      expect(transactions.length, 1);

      // nextRunAt advanced to next day (from today, not from missed date)
      final updatedRules = await recurringDs.getAll();
      expect(updatedRules.first.isActive, true);
      expect(
        updatedRules.first.nextRunAt.isAfter(DateTime(2026, 6, 5)),
        true,
      );
    });

    test('Delete rule → does not affect existing transactions', () async {
      // Create rule and generate
      await recurringVm.addRecurring(
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 1),
      );
      await recurringVm.checkAndGenerate();

      final transactionsBefore = await transactionDs.getAll();
      expect(transactionsBefore.length, 1);
      final txId = transactionsBefore.first.id;

      // Delete the rule
      final rule = (await recurringDs.getAll()).first;
      await recurringVm.deleteRecurring(rule.id);

      // Transactions remain
      final transactionsAfter = await transactionDs.getAll();
      expect(transactionsAfter.length, 1);
      expect(transactionsAfter.first.id, txId);
      expect(transactionsAfter.first.sourceRecurringId, rule.id);

      // Rule is gone
      final rules = await recurringDs.getAll();
      expect(rules, isEmpty);
    });

    test('Rule with weekly frequency → generate → nextRunAt 7 days later',
        () async {
      await recurringVm.addRecurring(
        categoryName: 'Ăn ngoài',
        amount: 50000,
        frequency: 'weekly',
        startDate: DateTime(2026, 6, 1),
      );

      await recurringVm.checkAndGenerate();

      final rules = await recurringDs.getAll();
      // nextRunAt should be 7 days after generation time (today ~2026-06-05)
      final diff = rules.first.nextRunAt.difference(DateTime(2026, 6, 1)).inDays;
      expect(diff, greaterThanOrEqualTo(6)); // at least 6 days (flexible on exact time)
    });

    test('Rule with monthly frequency → generate → nextRunAt ~30 days later',
        () async {
      await recurringVm.addRecurring(
        categoryName: 'Subscription',
        amount: 200000,
        frequency: 'monthly',
        startDate: DateTime(2026, 6, 1),
      );

      await recurringVm.checkAndGenerate();

      final rules = await recurringDs.getAll();
      final diff = rules.first.nextRunAt.difference(DateTime(2026, 6, 1)).inDays;
      expect(diff, greaterThanOrEqualTo(29)); // ~30 days
    });

    test('ExpenseViewModel can see transactions generated by recurring', () async {
      await recurringVm.addRecurring(
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 1),
      );
      await recurringVm.checkAndGenerate();

      // Refresh ExpenseViewModel to load generated transactions
      await expenseVm.refresh();

      // ExpenseViewModel should see the generated transaction
      expect(expenseVm.allTransactions.length, 1);
      expect(expenseVm.allTransactions.first.sourceRecurringId, isNotNull);
      expect(expenseVm.allTransactions.first.category, 'Cà phê');
    });

    test('Future-due rule → no generation', () async {
      final futureRule = RecurringTransaction(
        id: 'future-rule',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2099, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      await recurringDs.insert(futureRule);

      await recurringVm.checkAndGenerate();

      final transactions = await transactionDs.getAll();
      expect(transactions, isEmpty);
    });

    test('Toggle active → off → no generation', () async {
      await recurringVm.addRecurring(
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 1),
      );

      final ruleId = (await recurringDs.getAll()).first.id;
      await recurringVm.toggleActive(ruleId);

      await recurringVm.checkAndGenerate();

      final transactions = await transactionDs.getAll();
      expect(transactions, isEmpty);
    });

    test('Toggle inactive → on → generates', () async {
      final inactiveRule = RecurringTransaction(
        id: 'was-inactive',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: false,
        createdAt: DateTime(2026, 6, 1),
      );
      await recurringDs.insert(inactiveRule);

      // Toggle to active
      await recurringVm.toggleActive('was-inactive');

      await recurringVm.checkAndGenerate();

      final transactions = await transactionDs.getAll();
      expect(transactions.length, 1);
    });

    test('edit nextRunAt to future date → cold start generates only 1 tx',
        () async {
      // D1 scenario: user edits nextRunAt back to a past date that already
      // has a tx for this rule. Old code checked `today` and would WRONGLY
      // generate a duplicate. New code checks `ruleDate` and correctly skips.
      final ruleId = 'edit-next-runat';

      // Insert rule with nextRunAt in the past (e.g., 2026-06-01)
      final pastRule = RecurringTransaction(
        id: ruleId,
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      await recurringDs.insert(pastRule);

      // Manually insert a tx for ruleDate (2026-06-01) — simulates tx that
      // was previously generated for the rule's nextRunAt date.
      final existingTx = Transaction(
        id: 'existing-original',
        amount: 20000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 1),
        note: '',
        sourceRecurringId: ruleId,
      );
      await transactionDs.add(existingTx);

      // Trigger checkAndGenerate. today is 2026-06-06 (test runtime), but
      // rule.nextRunAt is 2026-06-01.
      // OLD code: check today (2026-06-06) → no tx → would generate duplicate
      // NEW code: check ruleDate (2026-06-01) → finds tx → skip
      await recurringVm.checkAndGenerate();

      // Should still have only 1 tx (not 2)
      final transactions = await transactionDs.getAll();
      expect(transactions.length, 1,
          reason: 'Safety net should prevent duplicate when tx exists for rule.nextRunAt date');
    });
  });
}

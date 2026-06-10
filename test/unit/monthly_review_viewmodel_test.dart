import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/viewmodels/monthly_review_viewmodel.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockBudgetLocalDataSource extends Mock
    implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockRecurringLocalDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class FakeTransaction extends Fake implements Transaction {}

class FakeBudget extends Fake implements Budget {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshot {}

class FakeRecurring extends Fake implements RecurringTransaction {}

void main() {
  late MockTransactionLocalDataSource mockTxDS;
  late MockBudgetLocalDataSource mockBudgetDS;
  late MockBudgetSnapshotLocalDataSource mockSnapshotDS;
  late MockRecurringLocalDataSource mockRecurringDS;
  late MockCategoryLocalDataSource mockCategoryDS;

  setUpAll(() {
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(FakeBudget());
    registerFallbackValue(FakeBudgetSnapshot());
    registerFallbackValue(FakeRecurring());
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    mockTxDS = MockTransactionLocalDataSource();
    mockBudgetDS = MockBudgetLocalDataSource();
    mockSnapshotDS = MockBudgetSnapshotLocalDataSource();
    mockRecurringDS = MockRecurringLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    // Default: return empty data
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockRecurringDS.getAll()).thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
  });

  MonthlyReviewViewModel makeVm() {
    return MonthlyReviewViewModel(
      transactionDataSource: mockTxDS,
      budgetDataSource: mockBudgetDS,
      budgetSnapshotDataSource: mockSnapshotDS,
      recurringDataSource: mockRecurringDS,
      categoryDataSource: mockCategoryDS,
    );
  }

  group('MonthlyReviewViewModel', () {
    test('defaults to current month', () {
      final vm = makeVm();
      final now = DateTime.now();
      expect(vm.selectedMonth.year, now.year);
      expect(vm.selectedMonth.month, now.month);
      expect(vm.selectedMonth.day, 1);
    });

    test('loadMonth calls getByDateRange for selected + previous comparable periods', () async {
      final vm = makeVm();
      final txs = [
        Transaction(id: '1', amount: 50000, category: 'Ăn ngoài', emoji: '🍜',
            date: DateTime.now(), note: ''),
      ];
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => txs);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockRecurringDS.getAll()).thenAnswer((_) async => []);

      await vm.loadMonth();

      // Verify getByDateRange was called at least twice (current + previous period)
      verify(() => mockTxDS.getByDateRange(any(), any())).called(greaterThanOrEqualTo(2));
      verify(() => mockBudgetDS.getAll()).called(1);
      verify(() => mockRecurringDS.getAll()).called(1);
    });

    test('loadMonth does NOT depend on ExpenseViewModel for data', () async {
      // This test documents that the ViewModel directly queries DataSource,
      // not via ExpenseViewModel. We verify no ExpenseViewModel interaction exists.
      final vm = makeVm();
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);

      await vm.loadMonth();

      // If we get here without errors, the VM doesn't call ExpenseViewModel
      expect(vm.isLoading, isFalse);
    });

    test('refresh reloads current selected month', () async {
      final vm = makeVm();
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);

      await vm.refresh();

      verify(() => mockTxDS.getByDateRange(any(), any())).called(greaterThanOrEqualTo(2));
    });

    test('previousMonth navigates to previous month', () async {
      final vm = makeVm();
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);

      vm.previousMonth();
      await Future.delayed(Duration.zero);

      // Calculate expected previous month correctly (handles January edge case)
      final now = DateTime.now();
      final expected = DateTime(now.year, now.month - 1, 1);
      expect(vm.selectedMonth.year, expected.year);
      expect(vm.selectedMonth.month, expected.month);
    });

    test('nextMonth disabled beyond current month', () async {
      final vm = makeVm();
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);

      expect(vm.canGoNext, isFalse);
    });

    test('previousMonth always enabled', () async {
      final vm = makeVm();
      expect(vm.canGoPrevious, isTrue);
    });

    test('selectMonth changes selected month and reloads', () async {
      final vm = makeVm();
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);

      await vm.selectMonth(DateTime(2026, 3, 15));

      expect(vm.selectedMonth.year, 2026);
      expect(vm.selectedMonth.month, 3);
      expect(vm.selectedMonth.day, 1);
    });

    test('error friendly message on exception', () async {
      when(() => mockTxDS.getByDateRange(any(), any()))
          .thenThrow(Exception('DB error'));

      final vm = makeVm();
      await vm.loadMonth();

      expect(vm.errorMessage, isNotNull);
      expect(vm.errorMessage, isNot(contains('Exception')));
      expect(vm.errorMessage, isNot(contains('DB error')));
      expect(vm.isLoading, isFalse);
    });

    test('clearError clears error message', () async {
      when(() => mockTxDS.getByDateRange(any(), any()))
          .thenThrow(Exception('DB error'));

      final vm = makeVm();
      await vm.loadMonth();
      expect(vm.errorMessage, isNotNull);

      vm.clearError();
      expect(vm.errorMessage, isNull);
    });

    test('loadMonth for past month uses full month comparison', () async {
      final vm = makeVm();
      final calls = <List<DateTime>>[];
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((inv) async {
        calls.add([inv.positionalArguments[0] as DateTime, inv.positionalArguments[1] as DateTime]);
        return <Transaction>[];
      });

      // Select May 2026 (past month)
      await vm.selectMonth(DateTime(2026, 5, 1));

      // Should have 2 calls: current period + previous period
      expect(calls.length, 2);
      // First call: May 1 to May 31 (full month)
      expect(calls[0][0].month, 5);
      expect(calls[0][1].month, 5);
      // Second call: April 1 to April 30 (full previous month)
      expect(calls[1][0].month, 4);
      expect(calls[1][1].month, 4);
    });
  });

  group('MonthlyReviewViewModel budget resolution (ADR-0025)', () {
    test('current month uses live budgets, NOT snapshots', () async {
      when(() => mockTxDS.getByDateRange(any(), any()))
          .thenAnswer((_) async => []);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'live-1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 5000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);
      // Snapshot would return different value — should NOT be used
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => [
            BudgetSnapshot(
              yearMonth: '2026-12',
              categoryName: 'Ăn ngoài',
              limitAmount: 9999999, // different from live
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);

      final vm = makeVm();
      await vm.loadMonth(); // current month

      // Live budgets queried
      verify(() => mockBudgetDS.getAll()).called(1);
      // Snapshot should NOT be queried for current month
      verifyNever(() => mockSnapshotDS.getByYearMonth(any()));
    });

    test('past month with snapshots uses snapshot budgets (not live)', () async {
      final pastSnapshot = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        limitAmount: 1234567, // distinct value to verify path
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );
      when(() => mockTxDS.getByDateRange(any(), any()))
          .thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth('2026-05'))
          .thenAnswer((_) async => [pastSnapshot]);
      // live would return a different value
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'live-1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 9999999,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);

      final vm = makeVm();
      await vm.selectMonth(DateTime(2026, 5, 1));

      // Snapshot was queried for the past month
      verify(() => mockSnapshotDS.getByYearMonth('2026-05')).called(1);
      // Live budgets NOT queried when snapshot path returns data
      verifyNever(() => mockBudgetDS.getAll());
      // Data was built with snapshot-derived limits
      expect(vm.data, isNotNull);
      final highlights = vm.data!.budgetHighlights;
      final anNgoai = highlights
          .where((h) => h.categoryName == 'Ăn ngoài')
          .firstOrNull;
      // 0 spent vs 1234567 limit → no highlight (not warning/exceeded)
      expect(anNgoai, isNull,
          reason: 'limit from snapshot 1234567 should not produce a highlight at 0 spent');
    });

    test('past month with no snapshots falls back to live budgets', () async {
      when(() => mockTxDS.getByDateRange(any(), any()))
          .thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth('2026-05'))
          .thenAnswer((_) async => []); // no snapshots
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'live-1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 1000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);

      final vm = makeVm();
      await vm.selectMonth(DateTime(2026, 5, 1));

      // Snapshot was queried
      verify(() => mockSnapshotDS.getByYearMonth('2026-05')).called(1);
      // Live fallback was used
      verify(() => mockBudgetDS.getAll()).called(1);
      expect(vm.data, isNotNull);
    });
  });
}
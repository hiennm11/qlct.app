import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/services/monthly_budget_plan_builder.dart';
import 'package:qlct/viewmodels/monthly_plan_viewmodel.dart';

class MockBudgetPlanDataSource extends Mock
    implements BudgetPlanLocalDataSource {}

class MockBudgetLocalDataSource extends Mock
    implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeBudgetPlan extends Fake implements BudgetPlan {}

class FakeBudgetPlanItem extends Fake implements BudgetPlanItem {}

class FakeBudget extends Fake implements Budget {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshot {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockBudgetPlanDataSource mockPlanDS;
  late MockBudgetLocalDataSource mockBudgetDS;
  late MockBudgetSnapshotLocalDataSource mockSnapshotDS;
  late MockTransactionLocalDataSource mockTxDS;
  late MockStorageService mockStorage;
  late MonthlyBudgetPlanBuilder builder;

  setUpAll(() {
    registerFallbackValue(FakeBudgetPlan());
    registerFallbackValue(FakeBudgetPlanItem());
    registerFallbackValue(FakeBudget());
    registerFallbackValue(FakeBudgetSnapshot());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(DateTime(2026, 6, 1));
  });

  setUp(() {
    mockPlanDS = MockBudgetPlanDataSource();
    mockBudgetDS = MockBudgetLocalDataSource();
    mockSnapshotDS = MockBudgetSnapshotLocalDataSource();
    mockTxDS = MockTransactionLocalDataSource();
    mockStorage = MockStorageService();
    builder = MonthlyBudgetPlanBuilder();
  });

  // Helper: make a simple transaction
  Transaction tx(String category, int amount, DateTime date) {
    return Transaction(
      id: 'tx-${date.millisecondsSinceEpoch}',
      amount: amount,
      category: category,
      emoji: '',
      date: date,
      note: '',
    );
  }

  // Helper: month start and end for a given DateTime
  (DateTime, DateTime) monthBounds(DateTime d) {
    final start = DateTime(d.year, d.month, 1);
    final end = DateTime(d.year, d.month + 1, 0);
    return (start, end);
  }

  // Helper: stub all defaults (call BEFORE constructing VM)
  void stubDefaultsForNewDraft() {
    when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
    when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});
  }

  group('initial state', () {
    test('targetMonth is next month from now', () {
      stubDefaultsForNewDraft();

      final now = DateTime.now();

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );

      final expected = DateTime(now.year, now.month + 1, 1);
      expect(vm.targetMonth, expected);
    });

    test('errorMessage starts null', () {
      stubDefaultsForNewDraft();

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: DateTime(2026, 6, 15),
      );
      expect(vm.errorMessage, null);
    });

    test('hasSavedDraft starts false', () {
      stubDefaultsForNewDraft();

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: DateTime(2026, 6, 15),
      );
      expect(vm.hasSavedDraft, false);
    });
  });

  group('load — existing draft', () {
    test('loads existing draft without recomputing suggestions', () async {
      const targetYMs = '2026-07-01';
      final existingPlan = BudgetPlan(
        yearMonth: targetYMs,
        plannedTotalBudget: 10000000,
        source: 'previousMonth',
        status: 'draft',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      final existingItems = [
        BudgetPlanItem(
          yearMonth: targetYMs,
          categoryName: 'Ăn ngoài',
          plannedLimit: 5000000,
          alertThreshold: 80,
          suggestedLimit: 5000000,
          baseLimit: 3000000,
          lastMonthSpent: 4000000,
          wasOverBudgetLastMonth: true,
          recommendation: 'increase',
        ),
      ];

      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => existingPlan);
      when(() => mockPlanDS.getItems(any())).thenAnswer((_) async => existingItems);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: DateTime(2026, 6, 15),
      );
      // Wait for constructor's Future.microtask to complete
      await Future.delayed(Duration.zero);

      expect(vm.data, isNotNull);
      expect(vm.data!.plan.yearMonth, targetYMs);
      expect(vm.data!.plan.status, 'draft');
      expect(vm.data!.items.length, 1);
      expect(vm.data!.items.first.categoryName, 'Ăn ngoài');
      expect(vm.data!.items.first.recommendation, 'increase');
      expect(vm.hasSavedDraft, true);
      // Should NOT call getByDateRange (no recompute)
      verifyNever(() => mockTxDS.getByDateRange(any(), any()));
    });
  });

  group('load — creates draft from previousMonth source', () {
    test('creates draft from previous-month snapshot fallback live budget',
        () async {
      final now = DateTime(2026, 6, 15);
      const prevYMs = '2026-05';

      final prevSnapshots = [
        BudgetSnapshot(
          yearMonth: prevYMs,
          categoryName: 'Ăn ngoài',
          limitAmount: 3000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 5, 1),
        ),
      ];

      final (rStart, rEnd) = monthBounds(DateTime(2026, 4, 1));
      final recentTxs = [
        tx('Ăn ngoài', 2500000, DateTime(2026, 4, 5)),
        tx('Ăn ngoài', 500000, DateTime(2026, 4, 10)),
      ];

      final (pStart, pEnd) = monthBounds(DateTime(2026, 5, 1));
      final prevTxs = [
        tx('Ăn ngoài', 3500000, DateTime(2026, 5, 3)),
      ];

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(prevYMs))
          .thenAnswer((_) async => prevSnapshots);
      when(() => mockSnapshotDS.getByYearMonth(any()))
          .thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(rStart, rEnd))
          .thenAnswer((_) async => recentTxs);
      when(() => mockTxDS.getByDateRange(pStart, pEnd))
          .thenAnswer((_) async => prevTxs);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      // Wait for constructor's Future.microtask to complete
      await Future.delayed(Duration.zero);

      expect(vm.data, isNotNull);
      expect(vm.data!.plan.yearMonth, '2026-07');
      expect(vm.data!.plan.source, 'previousMonth');
      expect(vm.data!.plan.status, 'draft');
      // load() calls saveDraft once via _createDraft
      verify(() => mockPlanDS.saveDraft(any(), any())).called(1);
      expect(vm.hasSavedDraft, true);
    });

    test('fallback to live budget when previous-month snapshot is empty',
        () async {
      final now = DateTime(2026, 6, 15);
      const prevYMs = '2026-05';

      final liveBudgets = [
        Budget(
          id: 'b1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 4000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 6, 1),
        ),
      ];

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockSnapshotDS.getByYearMonth(prevYMs))
          .thenAnswer((_) async => []); // empty snapshot
      when(() => mockSnapshotDS.getByYearMonth(any()))
          .thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      expect(vm.data, isNotNull);
      // Should use live budget as base
      verify(() => mockBudgetDS.getAll()).called(greaterThan(0));
    });
  });

  group('resetSource — currentBudget', () {
    test('creates draft from current live budget', () async {
      final now = DateTime(2026, 6, 15);

      final liveBudgets = [
        Budget(
          id: 'b1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 6, 1),
        ),
      ];

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(15000000);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.resetSource('currentBudget');

      expect(vm.data!.plan.source, 'currentBudget');
      verify(() => mockPlanDS.saveDraft(any(), any())).called(2);
    });
  });

  group('resetSource — empty', () {
    test('creates base-0 plan with suggestions', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.resetSource('empty');

      expect(vm.data!.plan.source, 'empty');
      // All items should have baseLimit=0
      for (final item in vm.data!.items) {
        expect(item.baseLimit, 0, reason: '${item.categoryName} baseLimit should be 0');
      }
    });
  });

  group('resetSource', () {
    test('previousMonth — rebuilds plan and saves', () async {
      final now = DateTime(2026, 6, 15);
      const prevYMs = '2026-05';

      final prevSnapshots = [
        BudgetSnapshot(
          yearMonth: prevYMs,
          categoryName: 'Ăn ngoài',
          limitAmount: 3000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 5, 1),
        ),
      ];

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(prevYMs))
          .thenAnswer((_) async => prevSnapshots);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);
      // No explicit load() — constructor's microtask already loaded

      await vm.resetSource('previousMonth');

      expect(vm.data!.plan.source, 'previousMonth');
      // load() called saveDraft once, resetSource calls it again
      verify(() => mockPlanDS.saveDraft(any(), any())).called(2);
    });

    test('currentBudget — rebuilds plan from live budget', () async {
      final now = DateTime(2026, 6, 15);

      final liveBudgets = [
        Budget(
          id: 'b1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 6, 1),
        ),
      ];

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.resetSource('currentBudget');

      expect(vm.data!.plan.source, 'currentBudget');
    });

    test('empty — creates base-0 plan and saves', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.resetSource('empty');

      expect(vm.data!.plan.source, 'empty');
      for (final item in vm.data!.items) {
        expect(item.baseLimit, 0);
      }
    });
  });

  group('updateItemLimit', () {
    test('updates plannedLimit for category and persists draft', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.updateItemLimit('Ăn ngoài', 6000000);

      final item = vm.data!.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
      expect(item.plannedLimit, 6000000);
      // load() saved once, updateItemLimit autosaves once
      verify(() => mockPlanDS.saveDraft(any(), any())).called(2);
      expect(vm.hasSavedDraft, true);
    });

    test('savedMessage is set after update', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.updateItemLimit('Ăn ngoài', 6000000);

      expect(vm.savedMessage, isNotNull);
    });
  });

  group('updatePlannedTotalBudget', () {
    test('updates plannedTotalBudget and persists', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      await vm.updatePlannedTotalBudget(20000000);

      expect(vm.data!.plan.plannedTotalBudget, 20000000);
      // load() saved once, updatePlannedTotalBudget autosaves once
      verify(() => mockPlanDS.saveDraft(any(), any())).called(2);
    });
  });

  group('recomputeSuggestions', () {
    test('rebuilds suggestions from latest transactions and saves', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any()))
          .thenAnswer((_) async => [
                tx('Ăn ngoài', 3000000, DateTime(2026, 3, 10)),
              ]);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      // Reset to empty source so base budgets are 0 and plannedLimit = suggested
      await vm.resetSource('empty');

      // Manually update a limit to verify it changes after recompute
      await vm.updateItemLimit('Ăn ngoài', 1000000);

      final itemBefore = vm.data!.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
      expect(itemBefore.plannedLimit, 1000000); // manual override

      await vm.recomputeSuggestions();

      // After recompute, data should be rebuilt (suggestion updated)
      final itemAfter = vm.data!.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
      // With 1 month of data, suggestedLimit = 3000000 → rounded to 3000000
      expect(itemAfter.suggestedLimit, 3000000);
      // plannedLimit = suggested (since source=empty)
      expect(itemAfter.plannedLimit, 3000000);
      // recomputeSuggestions persisted the rebuilt plan.
      // load() + resetSource('empty') + updateItemLimit saved 3 times so far.
      // This 4th save is the additional recomputeSuggestions persist.
      verify(() => mockPlanDS.saveDraft(any(), any())).called(4);
    });
  });

  group('investment exclusion', () {
    test('draft does not include investment categories', () async {
      final now = DateTime(2026, 6, 15);

      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: now,
      );
      await Future.delayed(Duration.zero);

      final investmentCategories = Category.predefined
          .where((c) => c.isInvestment)
          .map((c) => c.name)
          .toList();

      for (final invCat in investmentCategories) {
        expect(
          vm.data!.items.any((i) => i.categoryName == invCat),
          false,
          reason: '$invCat should be excluded from plan items',
        );
      }
    });
  });

  group('clearError', () {
    test('clears errorMessage', () async {
      // Set up ALL stubs BEFORE constructing VM
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
      when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      final vm = MonthlyPlanViewModel(
        budgetPlanDataSource: mockPlanDS,
        budgetDataSource: mockBudgetDS,
        budgetSnapshotDataSource: mockSnapshotDS,
        transactionDataSource: mockTxDS,
        storageService: mockStorage,
        builder: builder,
        now: DateTime(2026, 6, 15),
      );
      // Wait for constructor's Future.microtask to complete
      await Future.delayed(Duration.zero);

      expect(vm.errorMessage, null);

      // Simulate error by making saveDraft throw
      when(() => mockPlanDS.saveDraft(any(), any()))
          .thenThrow(Exception('Save failed'));

      await vm.updateItemLimit('Ăn ngoài', 5000000);

      expect(vm.errorMessage, isNotNull);

      vm.clearError();
      expect(vm.errorMessage, null);
    });
  });
}

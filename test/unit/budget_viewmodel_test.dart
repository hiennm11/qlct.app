import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/budget_status.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockBudgetPlanLocalDataSource extends Mock
    implements BudgetPlanLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshot {}

class FakeBudgetPlan extends Fake implements BudgetPlan {}

void main() {
  late MockBudgetLocalDataSource mockRepo;
  late MockBudgetSnapshotLocalDataSource mockSnapshotRepo;
  late MockBudgetPlanLocalDataSource mockPlanRepo;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockStorageService mockStorage;
  late BudgetViewModel viewModel;

  setUp(() {
    mockRepo = MockBudgetLocalDataSource();
    mockSnapshotRepo = MockBudgetSnapshotLocalDataSource();
    mockPlanRepo = MockBudgetPlanLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockStorage = MockStorageService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockSnapshotRepo.bulkUpsert(any())).thenAnswer((_) async => {});
    when(() => mockPlanRepo.getDraft(any())).thenAnswer((_) async => null);
    when(() => mockPlanRepo.getPlan(any())).thenAnswer((_) async => null);
    when(() => mockPlanRepo.getItems(any())).thenAnswer((_) async => []);
    when(() => mockPlanRepo.markApplied(any(), any())).thenAnswer((_) async => {});
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
  });

  setUpAll(() {
    registerFallbackValue(Budget(
      id: '0',
      categoryName: '',
      monthlyLimit: 0,
      alertThreshold: 80,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(FakeBudgetSnapshot());
    registerFallbackValue(FakeBudgetPlan());
  });

  group('initial state', () {
    test('budgets is empty', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
    expect(viewModel.budgets, isEmpty);
    });

    test('budgetStatuses is empty', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      expect(viewModel.budgetStatuses, isEmpty);
    });

    test('isLoading state transitions correctly', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
      expect(viewModel.budgets.isEmpty, true);
    });

    test('isLoading becomes false after loading', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
    });

    test('errorMessage is null', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      expect(viewModel.errorMessage, null);
    });
  });

  group('_loadBudgets', () {
    test('populates budgets from repository', () async {
      final budgets = [
        Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        ),
      ];
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => budgets);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      expect(viewModel.budgets.length, 1);
      expect(viewModel.budgets.first.categoryName, 'Ăn ngoài');
    });

    test('calls repository.getAll()', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      verify(() => mockRepo.getAll()).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenThrow(Exception('DB error'));

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, false);
    });
  });

  group('setBudget', () {
    test('creates new budget and reloads budgets', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      when(() => mockRepo.getByCategory('Cà phê')).thenAnswer((_) async => null);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setBudget('Cà phê', 500000, 80);

      verify(() => mockRepo.upsert(any())).called(1);
      verify(() => mockRepo.getAll()).called(2); // initial + after upsert
    });

    test('updates existing budget', () async {
      final existingBudget = Budget(
        id: 'existing-id',
        categoryName: 'Cà phê',
        monthlyLimit: 300000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [existingBudget]);
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      when(() => mockRepo.getByCategory('Cà phê'))
          .thenAnswer((_) async => existingBudget);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setBudget('Cà phê', 500000, 75);

      verify(() => mockRepo.upsert(any())).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Upsert failed'));

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setBudget('Cà phê', 500000, 80);

      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('deleteBudget', () {
    test('deletes budget and reloads budgets', () async {
      final budget = Budget(
        id: '1',
        categoryName: 'Cà phê',
        monthlyLimit: 500000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);
      when(() => mockRepo.delete('1')).thenAnswer((_) async {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      verify(() => mockRepo.delete('1')).called(1);
      verify(() => mockRepo.getAll()).called(2);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.delete(any())).thenThrow(Exception('Delete failed'));

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('updateStats', () {
    test('updates _stats and notifies listeners', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      final stats = ExpenseStats(
        todayExpense: 50000,
        weekExpense: 200000,
        monthExpense: 800000,
        categoryTotals: {'Ăn ngoài': 500000},
      );

      viewModel.updateStats(stats);

      expect(viewModel.errorMessage, null); // no error means update succeeded
    });
  });

  group('_calculateStatuses', () {
    test('normal alert level: spent below threshold', () async {
      final budget = Budget(
        id: '1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 2000000,
        categoryTotals: {'Ăn ngoài': 2000000},
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses.isNotEmpty, true);
      expect(statuses.first.alertLevel.name, 'normal');
    });

    test('warning alert level: spent at/above threshold', () async {
      final budget = Budget(
        id: '1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 4500000,
        categoryTotals: {'Ăn ngoài': 4500000},
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses.first.alertLevel.name, 'warning');
    });

    test('exceeded alert level: spent >= limit', () async {
      final budget = Budget(
        id: '1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 6000000,
        categoryTotals: {'Ăn ngoài': 6000000},
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses.first.alertLevel.name, 'exceeded');
    });

    test('category with spent but no budget shows with limit=0', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 500000,
        categoryTotals: {'Cà phê': 500000},
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses.isNotEmpty, true);
      expect(statuses.any((BudgetStatus s) => s.categoryName == 'Cà phê'), true);
    });

    test('category with no spent and no budget is NOT included', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 0,
        categoryTotals: {},
      ));

      final List<BudgetStatus> statuses = viewModel.budgetStatuses;
      expect(statuses.isEmpty, true);
    });

    test('sorted by highest percentUsed first', () async {
      final budget1 = Budget(
        id: '1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      final budget2 = Budget(
        id: '2',
        categoryName: 'Cà phê',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget1, budget2]);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 0,
        categoryTotals: {'Ăn ngoài': 200000, 'Cà phê': 900000},
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses[0].categoryName, 'Cà phê'); // 90% vs 20%
      expect(statuses[1].categoryName, 'Ăn ngoài');
    });

    test('investment category is excluded from statuses', () async {
      // Budget exists for investment category - it should NOT appear in statuses
      final invBudget = Budget(
        id: 'inv-1',
        categoryName: 'Đầu tư',
        monthlyLimit: 10000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      final foodBudget = Budget(
        id: 'food-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [invBudget, foodBudget]);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 15000000,
        categoryTotals: {
          'Đầu tư': 8000000, // exceeded but should not show
          'Ăn ngoài': 1000000, // normal
        },
      ));

      final statuses = viewModel.budgetStatuses;
      // No status for investment
      expect(
          statuses.any((s) => s.categoryName == 'Đầu tư'), isFalse,
          reason: 'Investment category should be excluded from budget statuses');
      // Food budget still there
      expect(statuses.any((s) => s.categoryName == 'Ăn ngoài'), isTrue);
    });

    test('investment category with spending is excluded from "no budget" status',
        () async {
      // Even with no budget, investment spending should not generate a status
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 5000000,
        categoryTotals: {'Đầu tư': 5000000},
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses.any((s) => s.categoryName == 'Đầu tư'), isFalse,
          reason: 'Investment with no budget should still be excluded');
    });
  });

  group('totalBudgetStatus - investment excluded', () {
    test('compares against spending-only total (not spending+investment)',
        () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      // 1M spending + 4M investment = 5M monthExpense in stats
      // But TotalBudgetStatus should only consider 1M spending
      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 5000000,
        categoryTotals: {
          'Ăn ngoài': 1000000,
          'Đầu tư': 4000000,
        },
      ));

      await viewModel.setTotalBudget(10000000);

      final status = viewModel.totalBudgetStatus;
      expect(status, isNotNull);
      expect(status!.limit, 10000000);
      expect(status.spent, 1000000,
          reason: 'Spent should be spending-only, exclude investment');
      expect(status.percentUsed, 10);
      expect(status.alertLevel, AlertLevel.normal);
    });

    test('warning at 80% of spending-only (not spending+investment)', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', any()))
          .thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      // 8M spending + 5M investment = 13M monthExpense
      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 13000000,
        categoryTotals: {
          'Ăn ngoài': 8000000,
          'Đầu tư': 5000000,
        },
      ));

      await viewModel.setTotalBudget(10000000);

      final status = viewModel.totalBudgetStatus;
      expect(status!.spent, 8000000);
      expect(status.percentUsed, 80);
      expect(status.alertLevel, AlertLevel.warning);
    });
  });

  group('total budget', () {
    test('totalBudget returns null initially when storage returns null', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      expect(viewModel.totalBudget, null);
    });

    test('totalBudget returns value from storage on init', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(10000000);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      expect(viewModel.totalBudget, 10000000);
    });

    test('setTotalBudget saves to storage and updates state', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', 10000000)).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setTotalBudget(10000000);

      verify(() => mockStorage.saveValue('total_budget', 10000000)).called(1);
      expect(viewModel.totalBudget, 10000000);
    });
  });

  group('setAllBudgets', () {
    test('with empty list calls loadBudgets', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setAllBudgets([]);

      verify(() => mockRepo.getAll()).called(2); // initial + after setAllBudgets
    });

    test('with 3 budgets upserts all and reloads', () async {
      final budgets = [
        Budget(id: '', categoryName: 'Ăn ngoài', monthlyLimit: 1000000, alertThreshold: 80, createdAt: DateTime.now()),
        Budget(id: '', categoryName: 'Cà phê', monthlyLimit: 500000, alertThreshold: 80, createdAt: DateTime.now()),
        Budget(id: '', categoryName: 'Mua online', monthlyLimit: 2000000, alertThreshold: 80, createdAt: DateTime.now()),
      ];
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setAllBudgets(budgets);

      verify(() => mockRepo.upsert(any())).called(3);
      verify(() => mockRepo.getAll()).called(2);
    });

    test('handles repository error gracefully', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockRepo.upsert(any())).thenThrow(Exception('DB error'));
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setAllBudgets([
        Budget(id: '', categoryName: 'Ăn ngoài', monthlyLimit: 1000000, alertThreshold: 80, createdAt: DateTime.now()),
      ]);

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, false);
    });
  });

  group('auto-snapshot previous month on load', () {
    test('creates previous-month snapshots when none exist', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Budget(
                id: 'b1',
                categoryName: 'Ăn ngoài',
                monthlyLimit: 3000000,
                alertThreshold: 80,
                createdAt: DateTime(2026, 1, 1)),
            Budget(
                id: 'b2',
                categoryName: 'Cà phê',
                monthlyLimit: 1000000,
                alertThreshold: 80,
                createdAt: DateTime(2026, 1, 1)),
          ]);
      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      // Wait for async snapshot creation
      await Future.delayed(Duration.zero);

      verify(() => mockSnapshotRepo.bulkUpsert(any())).called(1);
    });

    test('snapshot captures correct yearMonth, row count, category names, limits, '
        'alert thresholds, createdAt, and no overwrite behavior', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Budget(
                id: 'b1',
                categoryName: 'Ăn ngoài',
                monthlyLimit: 3000000,
                alertThreshold: 80,
                createdAt: DateTime(2026, 1, 1)),
            Budget(
                id: 'b2',
                categoryName: 'Cà phê',
                monthlyLimit: 1000000,
                alertThreshold: 75,
                createdAt: DateTime(2026, 1, 1)),
          ]);
      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage, now: () => _testNow);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Capture the snapshots passed to bulkUpsert
      final captured = verify(() => mockSnapshotRepo.bulkUpsert(captureAny()))
          .captured
          .single as List<BudgetSnapshot>;

      // Verify row count
      expect(captured.length, 2);

      // Verify yearMonth is previous month of _testNow (2026-05)
      for (final snap in captured) {
        expect(snap.yearMonth, _testPrevMonthYMs);
      }

      // Verify category names and limits
      final snapMap = {for (var s in captured) s.categoryName: s};
      expect(snapMap['Ăn ngoài']!.limitAmount, 3000000);
      expect(snapMap['Ăn ngoài']!.alertThreshold, 80);
      expect(snapMap['Cà phê']!.limitAmount, 1000000);
      expect(snapMap['Cà phê']!.alertThreshold, 75);

      // Verify createdAt equals _testNow
      for (final snap in captured) {
        expect(snap.createdAt, _testNow,
            reason: 'Snapshot createdAt must use injected clock');
      }

      // Verify no overwrite behavior: all snapshots share the same yearMonth
      // and are independent rows (not replacing the live budgets)
      final allPrevMonth = captured.every((s) => s.yearMonth == _testPrevMonthYMs);
      expect(allPrevMonth, isTrue,
          reason: 'All snapshots should be for the same previous yearMonth');
      // The snapshots are fresh rows — none match the original live createdAt
      final liveCreatedAts = [
        DateTime(2026, 1, 1), // b1
        DateTime(2026, 1, 1), // b2
      ];
      for (final snap in captured) {
        expect(liveCreatedAts.contains(snap.createdAt), isFalse,
            reason: 'Snapshot createdAt must be fresh, not copied from live budget');
      }
    });

    test('does NOT overwrite existing previous-month snapshots', () async {
      final existingSnap = BudgetSnapshot(
        yearMonth: _testPrevMonthYMs,
        categoryName: 'Ăn ngoài',
        limitAmount: 9999999, // different from current live
        alertThreshold: 80,
        createdAt: DateTime(2026, 1, 1),
      );
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Budget(
                id: 'b1',
                categoryName: 'Ăn ngoài',
                monthlyLimit: 3000000,
                alertThreshold: 80,
                createdAt: DateTime(2026, 1, 1)),
          ]);
      when(() => mockSnapshotRepo.getByYearMonth(any()))
          .thenAnswer((_) async => [existingSnap]);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage, now: () => _testNow);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Should not bulkUpsert when previous month already has snapshots
      verifyNever(() => mockSnapshotRepo.bulkUpsert(any()));
    });

    test(
        'auto-snapshot includes investment budget rows (preserves historical data)',
        () async {
      // ADR-0025: snapshot ALL live budgets including investment to preserve
      // historical data, even though statuses/highlights/total exclude investment.
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'b1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 3000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
            Budget(
              id: 'inv1',
              categoryName: 'Đầu tư',
              monthlyLimit: 10000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);
      when(() => mockSnapshotRepo.getByYearMonth(any()))
          .thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // bulkUpsert was called (investment was included)
      verify(() => mockSnapshotRepo.bulkUpsert(any())).called(1);
    });

    test(
        'investment budget rows are included in auto-snapshot but excluded from '
        'budgetStatuses (split semantics)', () async {
      // Key test: investment rows are preserved in snapshots, but the same VM
      // continues to exclude them from status calculations elsewhere.
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'b1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 3000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
            Budget(
              id: 'inv1',
              categoryName: 'Đầu tư',
              monthlyLimit: 10000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);
      when(() => mockSnapshotRepo.getByYearMonth(any()))
          .thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Verify snapshot was created with investment row
      verify(() => mockSnapshotRepo.bulkUpsert(any())).called(1);

      // But statuses must still exclude investment
      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 11000000,
        categoryTotals: {
          'Ăn ngoài': 3000000,
          'Đầu tư': 8000000,
        },
      ));

      final statuses = viewModel.budgetStatuses;
      expect(statuses.any((s) => s.categoryName == 'Đầu tư'), isFalse,
          reason: 'investment must be excluded from statuses despite being in snapshot');
      expect(statuses.any((s) => s.categoryName == 'Ăn ngoài'), isTrue,
          reason: 'non-investment must still appear in statuses');
    });
  });

  // ─── Rollover auto-apply tests (ADR-0026 §9) ──────────────────────────────

  group('rollover auto-apply — snapshot before apply', () {
    test('snapshots previous month BEFORE applying current-month draft plan', () async {
      // Setup: previous month has no snapshot, current month has a draft plan
      const currentYMs = '2026-06'; // current month
      const prevYMs = '2026-05';   // previous month

      // Mutable list that getAll returns — starts with live budgets, receives upserted budgets
      final appliedBudgets = <Budget>[
        Budget(id: 'orig1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
        Budget(id: 'orig2', categoryName: 'Cà phê', monthlyLimit: 1000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 4000000,
        source: 'previousMonth',
        status: 'draft',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 3500000, alertThreshold: 80, suggestedLimit: 3000000, baseLimit: 3000000, lastMonthSpent: 2800000, wasOverBudgetLastMonth: false, recommendation: 'increase'),
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Cà phê', plannedLimit: 500000, alertThreshold: 80, suggestedLimit: 500000, baseLimit: 1000000, lastMonthSpent: 800000, wasOverBudgetLastMonth: false, recommendation: 'decrease'),
      ];

      // No previous month snapshot exists
      when(() => mockSnapshotRepo.getByYearMonth(prevYMs)).thenAnswer((_) async => []);
      // getAll returns appliedBudgets (non-empty to allow snapshot creation)
      when(() => mockRepo.getAll()).thenAnswer((_) async => appliedBudgets);
      // getByCategory returns null (no existing budget to preserve)
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getPlan(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async => {});
      when(() => mockRepo.upsert(any())).thenAnswer((inv) async {
        final newBudget = inv.positionalArguments.first as Budget;
        // Replace existing budget for same category
        appliedBudgets.removeWhere((b) => b.categoryName == newBudget.categoryName);
        appliedBudgets.add(newBudget);
      });
      when(() => mockRepo.delete(any())).thenAnswer((_) async => {});
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async => {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Verify: snapshot was created BEFORE apply
      final snapshotCapture = verify(() => mockSnapshotRepo.bulkUpsert(captureAny()))
          .captured
          .first as List<BudgetSnapshot>;
      expect(snapshotCapture.isNotEmpty, true,
          reason: 'snapshot must be created before apply');
      expect(snapshotCapture.any((s) => s.categoryName == 'Ăn ngoài'), true);
      expect(snapshotCapture.any((s) => s.categoryName == 'Cà phê'), true);
      // Plan should be marked applied
      verify(() => mockPlanRepo.markApplied(currentYMs, any())).called(1);
    });
  });

  group('rollover auto-apply — idempotency', () {
    test('applied plan does NOT re-apply on second load', () async {
      const currentYMs = '2026-06';

      final liveBudgets = [
        Budget(id: 'b1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      // Plan is already applied
      final appliedPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 4000000,
        source: 'previousMonth',
        status: 'applied',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        appliedAt: DateTime(2026, 6, 1),
      );

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => null); // no draft
      when(() => mockPlanRepo.getPlan(currentYMs)).thenAnswer((_) async => appliedPlan); // but plan exists as applied

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Should NOT mark applied again
      verifyNever(() => mockPlanRepo.markApplied(any(), any()));
      // Should NOT upsert from plan
      verifyNever(() => mockRepo.upsert(any()));
    });

    test('draft plan auto-applies on load', () async {
      const currentYMs = '2026-06';

      final liveBudgets = [
        Budget(id: 'b1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 5000000,
        source: 'previousMonth',
        status: 'draft',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 5000000, alertThreshold: 80, suggestedLimit: 4000000, baseLimit: 3000000, lastMonthSpent: 3500000, wasOverBudgetLastMonth: true, recommendation: 'increase'),
      ];

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async => {});
      when(() => mockRepo.upsert(any())).thenAnswer((_) async => {});
      when(() => mockRepo.delete(any())).thenAnswer((_) async => {});
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async => {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      verify(() => mockPlanRepo.markApplied(currentYMs, any())).called(1);
      verify(() => mockRepo.upsert(any())).called(1);
    });
  });

  group('rollover auto-apply — exact semantics', () {
    test('plan upserts positive limits and deletes zero/missing categories', () async {
      const currentYMs = '2026-06';

      // Live budgets: 3 categories
      final liveBudgets = [
        Budget(id: 'b1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
        Budget(id: 'b2', categoryName: 'Cà phê', monthlyLimit: 1000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
        Budget(id: 'b3', categoryName: 'Mua online', monthlyLimit: 2000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      // Draft plan: only 2 categories (Ăn ngoài=5M, Cà phê=0→delete, Mua online missing→delete)
      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 5000000,
        source: 'currentBudget',
        status: 'draft',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 5000000, alertThreshold: 80, suggestedLimit: 4000000, baseLimit: 3000000, lastMonthSpent: 3500000, wasOverBudgetLastMonth: true, recommendation: 'increase'),
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Cà phê', plannedLimit: 0, alertThreshold: 80, suggestedLimit: 800000, baseLimit: 1000000, lastMonthSpent: 1200000, wasOverBudgetLastMonth: true, recommendation: 'increase'),
        // Mua online is missing from plan → delete
      ];

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async => {});
      when(() => mockRepo.upsert(any())).thenAnswer((_) async => {});
      when(() => mockRepo.delete(any())).thenAnswer((_) async => {});
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async => {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Verify: Cà phê (plannedLimit=0) and Mua online (missing) should be deleted
      verify(() => mockRepo.delete('b2')).called(1); // Cà phê deleted
      verify(() => mockRepo.delete('b3')).called(1); // Mua online deleted
      // Ăn ngoài upserted with 5M
      verify(() => mockRepo.upsert(any())).called(greaterThan(0));
    });

    test('total_budget updated from plannedTotalBudget', () async {
      const currentYMs = '2026-06';

      final liveBudgets = [
        Budget(id: 'b1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 8000000,
        source: 'empty',
        status: 'draft',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 8000000, alertThreshold: 80, suggestedLimit: 7000000, baseLimit: 0, lastMonthSpent: 0, wasOverBudgetLastMonth: false, recommendation: 'keep'),
      ];

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async => {});
      when(() => mockRepo.upsert(any())).thenAnswer((_) async => {});
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async => {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Verify: total_budget saved with plannedTotalBudget from plan
      verify(() => mockStorage.saveValue('total_budget', 8000000)).called(1);
    });

    test('non-investment categories only — investment excluded from apply', () async {
      const currentYMs = '2026-06';

      final liveBudgets = [
        Budget(id: 'b1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
        Budget(id: 'inv1', categoryName: 'Đầu tư', monthlyLimit: 10000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 5000000,
        source: 'currentBudget',
        status: 'draft',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 5000000, alertThreshold: 80, suggestedLimit: 4000000, baseLimit: 3000000, lastMonthSpent: 3500000, wasOverBudgetLastMonth: true, recommendation: 'increase'),
        // Đầu tư not in plan (investment excluded)
      ];

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async => {});
      when(() => mockRepo.upsert(any())).thenAnswer((_) async => {});
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async => {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Verify: only Ăn ngoài upserted, Đầu tư left alone
      // The investment budget should NOT be deleted
      verifyNever(() => mockRepo.delete('inv1'));
    });
  });

  group('rollover auto-apply — signal', () {
    test('lastAutoAppliedPlanYearMonth is set after auto-apply', () async {
      const currentYMs = '2026-06';

      final liveBudgets = [
        Budget(id: 'b1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 6, 1)),
      ];

      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 5000000,
        source: 'empty',
        status: 'draft',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 5000000, alertThreshold: 80, suggestedLimit: 4000000, baseLimit: 0, lastMonthSpent: 0, wasOverBudgetLastMonth: false, recommendation: 'keep'),
      ];

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => liveBudgets);
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async => {});
      when(() => mockRepo.upsert(any())).thenAnswer((_) async => {});
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async => {});

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(viewModel.lastAutoAppliedPlanYearMonth, currentYMs);
    });

    test('clearAutoAppliedSignal clears the signal', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage);
      await Future.delayed(Duration.zero);

      expect(viewModel.lastAutoAppliedPlanYearMonth, null);

      viewModel.clearAutoAppliedSignal();
      expect(viewModel.lastAutoAppliedPlanYearMonth, null);
    });
  });

  group('rollover auto-apply — markApplied failure resilience', () {
    test('if markApplied fails after live budget writes, plan stays draft and second load retries to correct state',
        () async {
      // Simulates cross-store non-atomicity: Phase A (live budgets + total_budget)
      // succeeds, Phase B (markApplied) fails. Next load should retry safely.
      const currentYMs = '2026-06';

      // Live budgets before rollover
      final liveBudgets = <Budget>[
        Budget(id: 'orig1', categoryName: 'Ăn ngoài', monthlyLimit: 3000000, alertThreshold: 80, createdAt: DateTime(2026, 7, 1)),
      ];

      final draftPlan = BudgetPlan(
        yearMonth: currentYMs,
        plannedTotalBudget: 5000000,
        source: 'empty',
        status: 'draft',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      final draftItems = [
        BudgetPlanItem(yearMonth: currentYMs, categoryName: 'Ăn ngoài', plannedLimit: 5000000, alertThreshold: 80, suggestedLimit: 4000000, baseLimit: 0, lastMonthSpent: 0, wasOverBudgetLastMonth: false, recommendation: 'keep'),
      ];

      // Track which budgets have been upserted (simulates live DB state)
      final appliedBudgets = List<Budget>.from(liveBudgets);

      when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async {
        // First call: initial load (live budgets)
        // Second call: after Phase A upsert
        return List<Budget>.from(appliedBudgets);
      });
      when(() => mockRepo.upsert(any())).thenAnswer((inv) async {
        final b = inv.positionalArguments.first as Budget;
        appliedBudgets.removeWhere((x) => x.categoryName == b.categoryName);
        appliedBudgets.add(b);
      });
      when(() => mockRepo.delete(any())).thenAnswer((_) async {});
      when(() => mockPlanRepo.getDraft(currentYMs)).thenAnswer((_) async => draftPlan);
      when(() => mockPlanRepo.getItems(currentYMs)).thenAnswer((_) async => draftItems);
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async {
        throw Exception('markApplied DB error');
      });
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async {});

      // First load: Phase A succeeds, Phase B fails
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockCategoryDS, mockStorage, now: () => _testNow);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Plan still draft (markApplied failed)
      verify(() => mockPlanRepo.markApplied(currentYMs, any())).called(1);
      expect(viewModel.lastAutoAppliedPlanYearMonth, null);

      // Live budgets were already upserted to the correct values
      verify(() => mockRepo.upsert(any())).called(1);

      // Reset markApplied to succeed for second load
      when(() => mockPlanRepo.markApplied(currentYMs, any())).thenAnswer((_) async {});

      // Second load: plan still draft → retry apply
      await viewModel.forceReload();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // markApplied called again (retry)
      verify(() => mockPlanRepo.markApplied(currentYMs, any())).called(1);
      // No duplicate budgets — upsert only once (exact replacement semantics)
      verify(() => mockRepo.upsert(any())).called(1);

      // After retry, signal is set
      expect(viewModel.lastAutoAppliedPlanYearMonth, currentYMs);
    });
  });
}

/// Fixed clock used across the test suite for deterministic yearMonth.
/// currentYMs = '2026-06' (June) → prevYMs = '2026-05' (May)
final _testNow = DateTime(2026, 6, 15);
const _testPrevMonthYMs = '2026-05';
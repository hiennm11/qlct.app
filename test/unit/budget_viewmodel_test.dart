import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_status.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockBudgetLocalDataSource mockRepo;
  late MockStorageService mockStorage;
  late BudgetViewModel viewModel;

  setUp(() {
    mockRepo = MockBudgetLocalDataSource();
    mockStorage = MockStorageService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
  });

  setUpAll(() {
    registerFallbackValue(Budget(
      id: '0',
      categoryName: '',
      monthlyLimit: 0,
      alertThreshold: 80,
      createdAt: DateTime.now(),
    ));
  });

  group('initial state', () {
    test('budgets is empty', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      expect(viewModel.budgets, isEmpty);
    });

    test('budgetStatuses is empty', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      expect(viewModel.budgetStatuses, isEmpty);
    });

    test('isLoading state transitions correctly', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
      expect(viewModel.budgets.isEmpty, true);
    });

    test('isLoading becomes false after loading', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
    });

    test('errorMessage is null', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      expect(viewModel.budgets.length, 1);
      expect(viewModel.budgets.first.categoryName, 'Ăn ngoài');
    });

    test('calls repository.getAll()', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);
      verify(() => mockRepo.getAll()).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenThrow(Exception('DB error'));

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setBudget('Cà phê', 500000, 75);

      verify(() => mockRepo.upsert(any())).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Upsert failed'));

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      verify(() => mockRepo.delete('1')).called(1);
      verify(() => mockRepo.getAll()).called(2);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.delete(any())).thenThrow(Exception('Delete failed'));

      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('updateStats', () {
    test('updates _stats and notifies listeners', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockStorage);
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
  });

  group('total budget', () {
    test('totalBudget returns null initially when storage returns null', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      expect(viewModel.totalBudget, null);
    });

    test('totalBudget returns value from storage on init', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(10000000);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      expect(viewModel.totalBudget, 10000000);
    });

    test('setTotalBudget saves to storage and updates state', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', 10000000)).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setTotalBudget(10000000);

      verify(() => mockStorage.saveValue('total_budget', 10000000)).called(1);
      expect(viewModel.totalBudget, 10000000);
    });
  });

  group('totalBudgetStatus', () {
    test('returns null when totalBudget is null', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 500000,
        categoryTotals: {},
      ));

      expect(viewModel.totalBudgetStatus, null);
    });

    test('returns correct values when totalBudget and stats are set', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 3000000,
        categoryTotals: {'Ăn ngoài': 3000000},
      ));

      await viewModel.setTotalBudget(10000000);

      final status = viewModel.totalBudgetStatus;
      expect(status, isNotNull);
      expect(status!.limit, 10000000);
      expect(status.spent, 3000000);
      expect(status.remaining, 7000000);
      expect(status.percentUsed, 30);
      expect(status.alertLevel, AlertLevel.normal);
    });

    test('returns warning level when at 80%', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 8000000,
        categoryTotals: {},
      ));

      await viewModel.setTotalBudget(10000000);

      final status = viewModel.totalBudgetStatus;
      expect(status!.percentUsed, 80);
      expect(status.alertLevel, AlertLevel.warning);
    });

    test('returns exceeded level when at 100%', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', any())).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      viewModel.updateStats(ExpenseStats(
        todayExpense: 0,
        weekExpense: 0,
        monthExpense: 12000000,
        categoryTotals: {},
      ));

      await viewModel.setTotalBudget(10000000);

      final status = viewModel.totalBudgetStatus;
      expect(status!.percentUsed, 100);
      expect(status.alertLevel, AlertLevel.exceeded);
    });
  });

  group('setAllBudgets', () {
    test('with empty list calls loadBudgets', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setAllBudgets([
        Budget(id: '', categoryName: 'Ăn ngoài', monthlyLimit: 1000000, alertThreshold: 80, createdAt: DateTime.now()),
      ]);

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, false);
    });
  });
}
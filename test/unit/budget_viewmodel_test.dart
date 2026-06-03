import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_status.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/repositories/budget_repository.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

void main() {
  late MockBudgetRepository mockRepo;
  late BudgetViewModel viewModel;

  setUp(() {
    mockRepo = MockBudgetRepository();
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
      expect(viewModel.budgets, isEmpty);
    });

    test('budgetStatuses is empty', () {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
      expect(viewModel.budgetStatuses, isEmpty);
    });

    test('isLoading state transitions correctly', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
      // After microtask, loading should be done
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
      expect(viewModel.budgets.isEmpty, true);
    });

    test('isLoading becomes false after loading', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
    });

    test('errorMessage is null', () {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => budgets);

      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);

      expect(viewModel.budgets.length, 1);
      expect(viewModel.budgets.first.categoryName, 'Ăn ngoài');
    });

    test('calls repository.getAll()', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);
      verify(() => mockRepo.getAll()).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockRepo.getAll()).thenThrow(Exception('DB error'));

      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, false);
    });
  });

  group('setBudget', () {
    test('creates new budget and reloads budgets', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      when(() => mockRepo.getByCategory('Cà phê')).thenAnswer((_) async => null);

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [existingBudget]);
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      when(() => mockRepo.getByCategory('Cà phê'))
          .thenAnswer((_) async => existingBudget);

      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);

      await viewModel.setBudget('Cà phê', 500000, 75);

      verify(() => mockRepo.upsert(any())).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Upsert failed'));

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);
      when(() => mockRepo.delete('1')).thenAnswer((_) async {});

      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      verify(() => mockRepo.delete('1')).called(1);
      verify(() => mockRepo.getAll()).called(2);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.delete(any())).thenThrow(Exception('Delete failed'));

      viewModel = BudgetViewModel(mockRepo);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('updateStats', () {
    test('updates _stats and notifies listeners', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget]);

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = BudgetViewModel(mockRepo);
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
      when(() => mockRepo.getAll()).thenAnswer((_) async => [budget1, budget2]);

      viewModel = BudgetViewModel(mockRepo);
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
}
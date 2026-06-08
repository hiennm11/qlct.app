import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/budget_status.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshot {}

void main() {
  late MockBudgetLocalDataSource mockRepo;
  late MockBudgetSnapshotLocalDataSource mockSnapshotRepo;
  late MockStorageService mockStorage;
  late BudgetViewModel viewModel;

  setUp(() {
    mockRepo = MockBudgetLocalDataSource();
    mockSnapshotRepo = MockBudgetSnapshotLocalDataSource();
    mockStorage = MockStorageService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockSnapshotRepo.bulkUpsert(any())).thenAnswer((_) async {});
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
  });

  group('initial state', () {
    test('budgets is empty', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      expect(viewModel.budgets, isEmpty);
    });

    test('budgetStatuses is empty', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      expect(viewModel.budgetStatuses, isEmpty);
    });

    test('isLoading state transitions correctly', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
      expect(viewModel.budgets.isEmpty, true);
    });

    test('isLoading becomes false after loading', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);
      expect(viewModel.isLoading, false);
    });

    test('errorMessage is null', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);

      expect(viewModel.budgets.length, 1);
      expect(viewModel.budgets.first.categoryName, 'Ăn ngoài');
    });

    test('calls repository.getAll()', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);
      verify(() => mockRepo.getAll()).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenThrow(Exception('DB error'));

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.setBudget('Cà phê', 500000, 75);

      verify(() => mockRepo.upsert(any())).called(1);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Upsert failed'));

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      verify(() => mockRepo.delete('1')).called(1);
      verify(() => mockRepo.getAll()).called(2);
    });

    test('sets errorMessage on exception', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.delete(any())).thenThrow(Exception('Delete failed'));

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);

      await viewModel.deleteBudget('Cà phê');

      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('updateStats', () {
    test('updates _stats and notifies listeners', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      expect(viewModel.totalBudget, null);
    });

    test('totalBudget returns value from storage on init', () {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(10000000);
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      expect(viewModel.totalBudget, 10000000);
    });

    test('setTotalBudget saves to storage and updates state', () async {
      when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
      when(() => mockStorage.saveValue('total_budget', 10000000)).thenAnswer((_) async {});
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Capture the snapshots passed to bulkUpsert
      final captured = verify(() => mockSnapshotRepo.bulkUpsert(captureAny()))
          .captured
          .single as List<BudgetSnapshot>;

      // Verify row count
      expect(captured.length, 2);

      // Verify yearMonth is previous month
      final now = DateTime.now();
      final prev = DateTime(now.year, now.month - 1, 1);
      final expectedYMs = '${prev.year.toString().padLeft(4, '0')}-${prev.month.toString().padLeft(2, '0')}';
      for (final snap in captured) {
        expect(snap.yearMonth, expectedYMs);
      }

      // Verify category names and limits
      final snapMap = {for (var s in captured) s.categoryName: s};
      expect(snapMap['Ăn ngoài']!.limitAmount, 3000000);
      expect(snapMap['Ăn ngoài']!.alertThreshold, 80);
      expect(snapMap['Cà phê']!.limitAmount, 1000000);
      expect(snapMap['Cà phê']!.alertThreshold, 75);

      // Verify createdAt is roughly now (within 5 seconds)
      final nowSnap = DateTime.now();
      for (final snap in captured) {
        expect(snap.createdAt.isAfter(nowSnap.subtract(const Duration(seconds: 5))), isTrue);
        expect(snap.createdAt.isBefore(nowSnap.add(const Duration(seconds: 5))), isTrue);
      }

      // Verify no overwrite behavior: all snapshots share the same yearMonth
      // and are independent rows (not replacing the live budgets)
      final allPrevMonth = captured.every((s) => s.yearMonth == expectedYMs);
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
        yearMonth: _prevMonth(),
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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

      viewModel = BudgetViewModel(mockRepo, mockSnapshotRepo, mockStorage);
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
}

String _prevMonth() {
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1, 1);
  return '${prev.year.toString().padLeft(4, '0')}-${prev.month.toString().padLeft(2, '0')}';
}
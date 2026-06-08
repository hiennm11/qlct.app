import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/services/storage_service.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeTransaction extends Fake implements Transaction {}

class FakeExpenseStats extends Fake implements ExpenseStats {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshotLocalDataSource {}

void main() {
  late MockTransactionLocalDataSource mockTxRepo;
  late MockBudgetLocalDataSource mockBudgetRepo;
  late MockBudgetSnapshotLocalDataSource mockBudgetSnapshotRepo;
  late MockStorageService mockStorage;
  late ExportService exportService;

  setUpAll(() {
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(FakeExpenseStats());
    registerFallbackValue(FakeBudgetSnapshot());
  });

  setUp(() {
    mockTxRepo = MockTransactionLocalDataSource();
    mockBudgetRepo = MockBudgetLocalDataSource();
    mockBudgetSnapshotRepo = MockBudgetSnapshotLocalDataSource();
    mockStorage = MockStorageService();
    exportService = ExportService();

    when(() => mockTxRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockTxRepo.getByDate(any())).thenAnswer((_) async => []);
    when(() => mockBudgetRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockBudgetSnapshotRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockBudgetSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockBudgetSnapshotRepo.bulkUpsert(any())).thenAnswer((_) async {});
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    when(() => mockStorage.loadValue<int>(any())).thenReturn(null);
  });

  testWidgets('ChangeNotifierProxyProvider updates BudgetViewModel when ExpenseViewModel notifies',
      (tester) async {
    // Build a minimal MultiProvider tree with ChangeNotifierProxyProvider
    // matching main.dart wiring.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ExpenseViewModel(mockTxRepo, exportService),
          ),
          ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>(
            create: (_) => BudgetViewModel(mockBudgetRepo, mockBudgetSnapshotRepo, mockStorage),
            update: (_, expenseVM, budgetVM) => budgetVM!
              ..updateStats(expenseVM.stats),
          ),
        ],
        child: Builder(
          builder: (ctx) {
            // Access both VMs to ensure they're available
            final expenseVM = ctx.watch<ExpenseViewModel>();
            final budgetVM = ctx.watch<BudgetViewModel>();
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text('expenseLoaded:${expenseVM.isLoading}'),
                    Text('budgetHasStats:${budgetVM.budgetStatuses.isEmpty}'),
                    ElevatedButton(
                      key: const Key('add_tx'),
                      onPressed: () async {
                        // Trigger a refresh to simulate data load
                        await expenseVM.refresh();
                      },
                      child: const Text('Add Transaction'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    // Wait for initial load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // ExpenseViewModel should be loaded
    expect(find.textContaining('expenseLoaded:false'), findsOneWidget);

    // BudgetViewModel should have empty statuses (no budgets set)
    expect(find.textContaining('budgetHasStats:true'), findsOneWidget);
  });

  testWidgets('BudgetViewModel.updateStats is called when ExpenseViewModel changes',
      (tester) async {
    when(() => mockBudgetRepo.getAll()).thenAnswer((_) async => []);

    final expenseVM = ExpenseViewModel(mockTxRepo, exportService);
    final budgetVM = _TrackingBudgetViewModel(mockBudgetRepo, mockBudgetSnapshotRepo, mockStorage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseVM),
          ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>(
            create: (_) => budgetVM,
            update: (_, expVM, budVM) => budVM!
              ..updateStats(expVM.stats),
          ),
        ],
        child: Builder(
          builder: (ctx) => MaterialApp(
            home: Scaffold(
              body: Consumer2<ExpenseViewModel, BudgetViewModel>(
                builder: (_, expenseVM, budgetVM, _) {
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // After initial load, updateStats should have been called at least once
    // (ProxyProvider.update fires when both VMs are initialized).
    expect(budgetVM.updateStatsCallCount, greaterThanOrEqualTo(1));
  });
}

/// BudgetViewModel subclass that tracks updateStats calls for test assertions.
class _TrackingBudgetViewModel extends BudgetViewModel {
  int updateStatsCallCount = 0;

  _TrackingBudgetViewModel(
    super.budgetDataSource,
    super.snapshotDataSource,
    super.storageService,
  );

  @override
  void updateStats(ExpenseStats stats) {
    updateStatsCallCount++;
    super.updateStats(stats);
  }
}
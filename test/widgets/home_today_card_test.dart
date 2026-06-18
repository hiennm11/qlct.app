import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/home_today_card.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockBudgetLocalDataSource extends Mock
    implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockBudgetPlanLocalDataSource extends Mock
    implements BudgetPlanLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshot {}

void main() {
  late MockTransactionLocalDataSource mockTxRepo;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockBudgetLocalDataSource mockBudgetRepo;
  late MockBudgetSnapshotLocalDataSource mockSnapshotRepo;
  late MockBudgetPlanLocalDataSource mockPlanRepo;
  late MockStorageService mockStorage;
  late ExportService exportService;
  late ExpenseViewModel expenseVM;
  late BudgetViewModel budgetVM;

  setUpAll(() {
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      categoryId: 'test',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
    registerFallbackValue(Budget(
      id: '0',
      categoryName: '',
      categoryId: 'fallback',
      monthlyLimit: 0,
      alertThreshold: 80,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(FakeBudgetSnapshot());
    registerFallbackValue(BudgetPlan(
      yearMonth: '2026-01',
      plannedTotalBudget: 0,
      source: 'test',
      status: 'draft',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  setUp(() {
    mockTxRepo = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockBudgetRepo = MockBudgetLocalDataSource();
    mockSnapshotRepo = MockBudgetSnapshotLocalDataSource();
    mockPlanRepo = MockBudgetPlanLocalDataSource();
    mockStorage = MockStorageService();
    exportService = ExportService();

    // Default: empty txs.
    when(() => mockTxRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockTxRepo.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);

    // BudgetVM stubs.
    when(() => mockBudgetRepo.getAll()).thenAnswer((_) async => <Budget>[]);
    when(() => mockBudgetRepo.upsert(any())).thenAnswer((_) async {});
    when(() => mockBudgetRepo.delete(any())).thenAnswer((_) async {});
    when(() => mockSnapshotRepo.getByYearMonth(any()))
        .thenAnswer((_) async => <BudgetSnapshot>[]);
    when(() => mockPlanRepo.getDraft(any())).thenAnswer((_) async => null);
    when(() => mockPlanRepo.getItems(any()))
        .thenAnswer((_) async => <BudgetPlanItem>[]);

    // No total budget by default — tests opt in.
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    when(() => mockStorage.loadValue<bool>(any())).thenReturn(null);
  });

  Widget wrap({required int? totalBudget, required List<Transaction> txs}) {
    when(() => mockStorage.loadValue<int>('total_budget'))
        .thenReturn(totalBudget);
    when(() => mockTxRepo.getAll()).thenAnswer((_) async => txs);
    when(() => mockTxRepo.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);

    expenseVM = ExpenseViewModel(mockTxRepo, exportService, mockCategoryDS);
    budgetVM = BudgetViewModel(
      mockBudgetRepo,
      mockSnapshotRepo,
      mockPlanRepo,
      mockCategoryDS,
      mockStorage,
    );
    // Wire proxy: push ExpenseVM stats → BudgetVM so totalBudgetStatus computes.
    // Note: must call after `expenseVM` constructed but before pumpWidget so
    // Consumer2 sees a settled state.
    budgetVM.updateStats(expenseVM.stats);
    // Force settle the budget load so _loadBudgetsFuture resolves.
    budgetVM.forceReload();

    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
            ChangeNotifierProvider<BudgetViewModel>.value(value: budgetVM),
          ],
          child: const HomeTodayCard(),
        ),
      ),
    );
  }

  group('ADR-0081 HomeTodayCard', () {
    testWidgets('render với today expense + progress bar khi có total budget',
        (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final txs = [
        Transaction(
          id: 'tx-1',
          amount: 50000,
          category: 'Cà phê',
          categoryId: 'coffee',
          emoji: '☕',
          date: today,
        ),
        Transaction(
          id: 'tx-2',
          amount: 120000,
          category: 'Ăn ngoài',
          categoryId: 'food_out',
          emoji: '🍜',
          date: today,
        ),
      ];

      await tester.pumpWidget(wrap(totalBudget: 5000000, txs: txs));
      await tester.pumpAndSettle();

      // Card renders (không empty).
      expect(find.byKey(const Key('home-today-card')), findsOneWidget);
      // Empty state không hiển thị.
      expect(find.byKey(const Key('home-today-empty')), findsNothing);

      // Big number: 50k + 120k = 170k. CurrencyFormatter (vi_VN) outputs
      // digits grouped by '.' + prepend U+00A0 (NBSP) trước ₫ — đọc qua
      // widget.data để tránh whitespace literal trap khi viết expected.
      final amountFinder = find.byKey(const Key('home-today-amount'));
      expect(amountFinder, findsOneWidget);
      final amountText = (tester.widget<Text>(amountFinder)).data!;
      expect(amountText.contains('170.000'), isTrue,
          reason: 'Big number phải chứa "170.000", got: "$amountText"');
      expect(amountText.contains('₫'), isTrue,
          reason: 'Big number phải kết thúc bằng ₫, got: "$amountText"');

      // Tx count = 2.
      expect(find.text('2 giao dịch'), findsOneWidget);

      // Remaining + progress bar visible.
      expect(find.byKey(const Key('home-today-remaining')), findsOneWidget);
      expect(find.byKey(const Key('home-today-progress')), findsOneWidget);
    });

    testWidgets('empty state khi todayExpense=0 VÀ totalBudget=null',
        (tester) async {
      // txs = [] → today=0, totalBudget=null → SizedBox.shrink empty.
      await tester.pumpWidget(wrap(totalBudget: null, txs: []));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-today-empty')), findsOneWidget);
      expect(find.byKey(const Key('home-today-card')), findsNothing);
      expect(find.byKey(const Key('home-today-progress')), findsNothing);
    });
  });
}

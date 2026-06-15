import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/weekly_review_data.dart';
import 'package:qlct/services/weekly_review_builder.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/viewmodels/weekly_review_viewmodel.dart';
import 'package:qlct/widgets/weekly_review_card.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockRecurringLocalDataSource extends Mock implements RecurringLocalDataSource {}

class MockCategoryLocalDataSource extends Mock implements CategoryLocalDataSource {}

class FakeWeeklyReviewBuilder extends Fake implements WeeklyReviewBuilder {
  final WeeklyReviewData Function(
    List<Transaction>,
    List<Transaction>,
    List<Budget>,
    List<RecurringTransaction>,
    List<Category>,
    DateTime,
    DateTime,
    DateTime,
    DateTime,
    DateTime,
  ) builder;

  FakeWeeklyReviewBuilder(this.builder);

  @override
  WeeklyReviewData build({
    required List<Transaction> currentWeekTransactions,
    required List<Transaction> previousCompareTransactions,
    required List<Budget> budgets,
    required List<RecurringTransaction> activeRecurring,
    required List<Category> categories,
    required DateTime currentWeekStart,
    required DateTime currentWeekEnd,
    required DateTime previousCompareStart,
    required DateTime previousCompareEnd,
    required DateTime now,
  }) {
    return builder(
      currentWeekTransactions,
      previousCompareTransactions,
      budgets,
      activeRecurring,
      categories,
      currentWeekStart,
      currentWeekEnd,
      previousCompareStart,
      previousCompareEnd,
      now,
    );
  }
}

Category _makeCat({
  required String id,
  required String name,
  required String emoji,
  required CategoryKind kind,
  int sortOrder = 1,
}) {
  final dt = DateTime(2026, 1, 1);
  return Category(
    id: id,
    name: name,
    normalizedName: name,
    emoji: emoji,
    kind: kind,
    budgetBehavior:
        kind == CategoryKind.investment ? BudgetBehavior.excluded : BudgetBehavior.flexible,
    quickAmountMin: 10000,
    quickAmountDefault: 50000,
    quickAmountMax: 1000000,
    voicePhrases: const [],
    sortOrder: sortOrder,
    isSystem: true,
    isArchived: false,
    createdAt: dt,
    updatedAt: dt,
  );
}

Widget _harness({
  required WeeklyReviewViewModel weeklyVM,
  required CategoryViewModel catVM,
  required VoidCallback onCtaTap,
  required VoidCallback onTopCategoryTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<WeeklyReviewViewModel>.value(value: weeklyVM),
          ChangeNotifierProvider<CategoryViewModel>.value(value: catVM),
        ],
        child: WeeklyReviewCard(
          onCtaTap: onCtaTap,
          onTopCategoryTap: onTopCategoryTap,
        ),
      ),
    ),
  );
}

void main() {
  late MockTransactionLocalDataSource mockTxDS;
  late MockBudgetLocalDataSource mockBudgetDS;
  late MockRecurringLocalDataSource mockRecurringDS;
  late MockCategoryLocalDataSource mockCatDS;

  final catFood = _makeCat(id: 'cat-food', name: 'Ăn ngoài', emoji: '🍜', kind: CategoryKind.spending, sortOrder: 1);
  final catCoffee = _makeCat(id: 'cat-coffee', name: 'Cà phê', emoji: '☕', kind: CategoryKind.spending, sortOrder: 2);
  final catTransport = _makeCat(id: 'cat-transport', name: 'Đi lại', emoji: '🚌', kind: CategoryKind.spending, sortOrder: 3);
  final allCategories = [catFood, catCoffee, catTransport];

  setUp(() {
    mockTxDS = MockTransactionLocalDataSource();
    mockBudgetDS = MockBudgetLocalDataSource();
    mockRecurringDS = MockRecurringLocalDataSource();
    mockCatDS = MockCategoryLocalDataSource();
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
    when(() => mockRecurringDS.getAll()).thenAnswer((_) async => []);
    when(() => mockCatDS.getAll()).thenAnswer((_) async => []);
  });

  testWidgets('renders empty state when lowDataState=empty', (tester) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final fakeBuilder = FakeWeeklyReviewBuilder(
      (_, __, ___, ____, _____, ________, _________, __________, ___________, ____________) {
        return WeeklyReviewData(
          currentWeekStart: weekStart,
          currentWeekEnd: now,
          previousCompareStart: weekStart.subtract(const Duration(days: 7)),
          previousCompareEnd: weekStart.subtract(const Duration(days: 7)),
          weekSpent: 0,
          prevWeekSpent: 0,
          spendingDelta: 0,
          lowDataState: WeeklyReviewLowDataState.empty,
        );
      },
    );

    final weeklyVM = WeeklyReviewViewModel(
      transactionDataSource: mockTxDS,
      budgetDataSource: mockBudgetDS,
      recurringDataSource: mockRecurringDS,
      categoryDataSource: mockCatDS,
      builder: fakeBuilder,
    );
    // Force-load through public API to populate _data
    await weeklyVM.load();
    await tester.pumpAndSettle();

    final catVM = CategoryViewModel.seeded(allCategories);
    await tester.pumpWidget(_harness(
      weeklyVM: weeklyVM,
      catVM: catVM,
      onCtaTap: () {},
      onTopCategoryTap: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('state-weekly-review-empty')), findsOneWidget);
    expect(find.byKey(const Key('state-weekly-review-empty-hint')), findsOneWidget);
    expect(find.text('Chưa có giao dịch tuần này'), findsOneWidget);
    expect(find.textContaining('Bắt đầu thêm giao dịch'), findsOneWidget);
  });

  testWidgets('renders card with 3 insight chips when lowDataState=normal', (tester) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final fakeBuilder = FakeWeeklyReviewBuilder(
      (_, __, ___, ____, _____, ________, _________, __________, ___________, ____________) {
        return WeeklyReviewData(
          currentWeekStart: weekStart,
          currentWeekEnd: now,
          previousCompareStart: weekStart.subtract(const Duration(days: 7)),
          previousCompareEnd: weekStart.subtract(const Duration(days: 7)),
          weekSpent: 350000,
          prevWeekSpent: 100000,
          spendingDelta: 250000,
          topCategoryId: 'cat-food',
          topCategoryDelta: 200000,
          topCategoryCurrentSpent: 250000,
          topCategoryPrevSpent: 50000,
          daysLogged: 4,
          upcomingRecurringCount: 2,
          hasEnoughDataForDelta: true,
          lowDataState: WeeklyReviewLowDataState.normal,
        );
      },
    );

    final weeklyVM = WeeklyReviewViewModel(
      transactionDataSource: mockTxDS,
      budgetDataSource: mockBudgetDS,
      recurringDataSource: mockRecurringDS,
      categoryDataSource: mockCatDS,
      builder: fakeBuilder,
    );
    await weeklyVM.load();
    await tester.pumpAndSettle();

    final catVM = CategoryViewModel.seeded(allCategories);
    await tester.pumpWidget(_harness(
      weeklyVM: weeklyVM,
      catVM: catVM,
      onCtaTap: () {},
      onTopCategoryTap: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('state-weekly-review-card')), findsOneWidget);
    expect(find.byKey(const Key('state-weekly-review-insight-primary')), findsOneWidget);
    expect(find.byKey(const Key('state-weekly-review-insight-secondary')), findsOneWidget);
    expect(find.byKey(const Key('state-weekly-review-insight-tertiary')), findsOneWidget);
    expect(find.byKey(const Key('state-weekly-review-cta')), findsOneWidget);
    expect(find.textContaining('Ăn ngoài'), findsOneWidget);
    expect(find.textContaining('200.000'), findsOneWidget);
    expect(find.textContaining('2 khoản định kỳ'), findsOneWidget);
  });

  testWidgets('CTA tap fires onCtaTap callback', (tester) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final fakeBuilder = FakeWeeklyReviewBuilder(
      (_, __, ___, ____, _____, ________, _________, __________, ___________, ____________) {
        return WeeklyReviewData(
          currentWeekStart: weekStart,
          currentWeekEnd: now,
          previousCompareStart: weekStart.subtract(const Duration(days: 7)),
          previousCompareEnd: weekStart.subtract(const Duration(days: 7)),
          weekSpent: 100000,
          prevWeekSpent: 50000,
          spendingDelta: 50000,
          topCategoryId: 'cat-food',
          topCategoryDelta: 50000,
          topCategoryCurrentSpent: 100000,
          topCategoryPrevSpent: 50000,
          daysLogged: 2,
          hasEnoughDataForDelta: true,
          lowDataState: WeeklyReviewLowDataState.normal,
        );
      },
    );

    final weeklyVM = WeeklyReviewViewModel(
      transactionDataSource: mockTxDS,
      budgetDataSource: mockBudgetDS,
      recurringDataSource: mockRecurringDS,
      categoryDataSource: mockCatDS,
      builder: fakeBuilder,
    );
    await weeklyVM.load();
    await tester.pumpAndSettle();

    var ctaTapped = 0;
    var topCatTapped = 0;
    final catVM = CategoryViewModel.seeded(allCategories);
    await tester.pumpWidget(_harness(
      weeklyVM: weeklyVM,
      catVM: catVM,
      onCtaTap: () => ctaTapped++,
      onTopCategoryTap: () => topCatTapped++,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('state-weekly-review-cta')));
    await tester.pumpAndSettle();
    expect(ctaTapped, 1);

    await tester.tap(find.byKey(const Key('state-weekly-review-insight-secondary')));
    await tester.pumpAndSettle();
    expect(topCatTapped, 1);
  });
}

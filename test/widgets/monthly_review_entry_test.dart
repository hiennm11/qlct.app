import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/monthly_review_viewmodel.dart';
import 'package:qlct/widgets/stats_widget.dart';
import 'package:qlct/views/monthly_review_screen.dart';

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

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockTransactionLocalDataSource mockTxDS;
  late MockBudgetLocalDataSource mockBudgetDS;
  late MockBudgetSnapshotLocalDataSource mockSnapshotDS;
  late MockRecurringLocalDataSource mockRecurringDS;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockExportService mockExport;

  setUpAll(() {
    // NOTE: no initializeDateFormatting('vi_VN') needed — header label uses
    // static Vietnamese month names, no locale-data dependency.
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
  });

  setUp(() {
    mockTxDS = MockTransactionLocalDataSource();
    mockBudgetDS = MockBudgetLocalDataSource();
    mockSnapshotDS = MockBudgetSnapshotLocalDataSource();
    mockRecurringDS = MockRecurringLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockExport = MockExportService();
    when(() => mockTxDS.getAllPaginated(
            offset: any(named: 'offset'), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
    when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockRecurringDS.getAll()).thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
  });

  testWidgets('tapping monthly stats card opens MonthlyReviewScreen', (tester) async {
    final today = DateTime.now();
    final tx = Transaction(
      id: 'tx-1',
      amount: 50000,
      category: 'Ăn ngoài',
      emoji: '🍜',
      date: DateTime(today.year, today.month, today.day),
      note: '',
    );
    when(() => mockTxDS.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => [tx]);
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => [tx]);
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => []);
    when(() => mockRecurringDS.getAll()).thenAnswer((_) async => []);

    final expenseVm = ExpenseViewModel(mockTxDS, mockExport, mockCategoryDS);
    final reviewVm = MonthlyReviewViewModel(
      transactionDataSource: mockTxDS,
      budgetDataSource: mockBudgetDS,
      budgetSnapshotDataSource: mockSnapshotDS,
      recurringDataSource: mockRecurringDS,
      categoryDataSource: mockCategoryDS,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVm),
            ChangeNotifierProvider<MonthlyReviewViewModel>.value(value: reviewVm),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: StatsWidget(
                onTapMonth: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiProvider(
                        providers: [
                          ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVm),
                          ChangeNotifierProvider<MonthlyReviewViewModel>.value(value: reviewVm),
                        ],
                        child: const MonthlyReviewScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the month card
    final monthCard = find.text('THÁNG NÀY');
    expect(monthCard, findsOneWidget);
    await tester.tap(monthCard);
    await tester.pumpAndSettle();

    // MonthlyReviewScreen should be visible
    expect(find.byType(MonthlyReviewScreen), findsOneWidget);
  });
}
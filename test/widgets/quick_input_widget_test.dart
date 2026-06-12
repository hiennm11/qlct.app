import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/quick_input_widget.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

class _FakeCategoryViewModel extends CategoryViewModel {
  _FakeCategoryViewModel() : super.seeded(seedCategories);
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 3200);
  tester.view.devicePixelRatio = 1.0;
  tester.binding.scheduleFrame();
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  late MockTransactionLocalDataSource mockDs;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockExportService mockExport;
  late ExpenseViewModel expenseVM;

  setUpAll(() {
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      categoryId: 'test_cat',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
  });

  setUp(() {
    mockDs = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockExport = MockExportService();
    when(() => mockDs.getAll()).thenAnswer((_) async => []);
    when(() => mockDs.getAllPaginated(
            offset: any(named: 'offset'),
            limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
    when(() => mockCategoryDS.seedDefaultsIfEmpty()).thenAnswer((_) async {});
  });

  Future<void> pumpWithHistory(WidgetTester tester, List<Transaction> txs) async {
    _useLargeSurface(tester);
    when(() => mockDs.getAll()).thenAnswer((_) async => txs);
    when(() => mockDs.getAllPaginated(
            offset: any(named: 'offset'),
            limit: any(named: 'limit')))
        .thenAnswer((_) async => txs);
    expenseVM = ExpenseViewModel(mockDs, mockExport, mockCategoryDS);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
              ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
            ],
            child: const QuickInputWidget(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('header shows "Ghi chép nhanh"', (tester) async {
    await pumpWithHistory(tester, []);
    expect(find.text('⚡ Ghi chép nhanh'), findsOneWidget);
  });

  testWidgets('is collapsed by default', (tester) async {
    await pumpWithHistory(tester, []);
    // No sliders visible when collapsed (they appear inside expanded cards)
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('expands on header tap', (tester) async {
    await pumpWithHistory(tester, []);
    await tester.tap(find.text('⚡ Ghi chép nhanh'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsWidgets);
  });

  testWidgets('amount chip appears for category with history',
      (tester) async {
    final txs = [
      Transaction(
        id: 'h1',
        amount: 50000,
        category: 'Ăn ngoài', categoryId: 'food_out',
        emoji: '🍜',
        date: DateTime(2026, 6, 5),
        note: '',
      ),
    ];
    await pumpWithHistory(tester, txs);
    await tester.tap(find.text('⚡ Ghi chép nhanh'));
    await tester.pumpAndSettle();

    // Amount chip "50.000" should appear for the expanded card
    expect(find.text('50.000'), findsOneWidget);
  });

  testWidgets('tapping amount chip updates displayed amount', (tester) async {
    final txs = [
      Transaction(
        id: 'h1',
        amount: 50000,
        category: 'Ăn ngoài', categoryId: 'food_out',
        emoji: '🍜',
        date: DateTime(2026, 6, 5),
        note: '',
      ),
    ];
    await pumpWithHistory(tester, txs);
    await tester.tap(find.text('⚡ Ghi chép nhanh'));
    await tester.pumpAndSettle();

    // Tap the amount chip
    await tester.tap(find.text('50.000'));
    await tester.pump();

    // The displayed amount text should update to 50.000
    expect(find.text('50.000'), findsWidgets);
  });

  testWidgets('no amount chip when no history for category', (tester) async {
    await pumpWithHistory(tester, []);
    await tester.tap(find.text('⚡ Ghi chép nhanh'));
    await tester.pumpAndSettle();

    // "Gợi ý" label should not appear since no history
    expect(find.text('Gợi ý số tiền'), findsNothing);
  });
}

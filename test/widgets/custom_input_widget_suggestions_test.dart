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
import 'package:qlct/widgets/custom_input_widget.dart';
import 'package:qlct/services/transaction_suggestion_engine.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

/// Fake CategoryViewModel backed by seed categories.
/// Uses the seeded constructor so data is available immediately.
class _FakeCategoryViewModel extends CategoryViewModel {
  _FakeCategoryViewModel() : super.seeded(seedCategories);
}

/// Sets a large test viewport so PopupMenu / showMenu (positioned via
/// localToGlobal) renders inside the visible bounds. The category picker
/// uses showMenu, which sizes the menu from its parent constraints; in the
/// default 800x600 surface, the menu rect ends up at ~256px wide because
/// Flutter clips aggressively near the screen edge.
void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 3200);
  tester.view.devicePixelRatio = 1.0;
  // Pump once so the new view size propagates to the MediaQuery.
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
  });

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    expenseVM = ExpenseViewModel(mockDs, mockExport, mockCategoryDS);
    await tester.pump();
    await tester.pump();
  }

  /// Standard build: wraps in SizedBox + SingleChildScrollView so the widget
  /// has a fixed, wide enough constraint and can scroll if needed.
  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
              ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
            ],
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CustomInputWidget(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the category picker menu, then taps the PopupMenuItem whose
  /// value matches [categoryName].
  ///
  /// The menu uses showMenu() and creates PopupMenuItem<String> entries in
  /// an Overlay. We find all items by type and inspect the `value` field to
  /// avoid ambiguity with text rendered in the main widget tree.
  Future<void> selectCategory(WidgetTester tester, String categoryName) async {
    // Find the GestureDetector with GlobalKey (category picker)
    final pickerFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.key is GlobalKey,
    );
    expect(pickerFinder, findsOneWidget);
    await tester.tap(pickerFinder.first);
    await tester.pumpAndSettle();

    // The popup menu is rendered via Overlay. Find PopupMenuItem<String>
    // widgets and pick the one whose value matches.
    final itemFinder = find.byWidgetPredicate(
      (w) =>
          w is PopupMenuItem<String> && (w).value == categoryName,
    );
    expect(itemFinder, findsOneWidget,
        reason: 'category "$categoryName" should appear in the menu');

    await tester.tap(itemFinder);
    await tester.pumpAndSettle();
  }

  testWidgets('no suggestion chips when no category selected', (tester) async {
    await pumpUntilLoaded(tester);
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('Gợi ý số tiền'), findsNothing);
    expect(find.text('Gợi ý ghi chú'), findsNothing);
  });

  testWidgets('renders without crashing with empty allTransactions',
      (tester) async {
    await pumpUntilLoaded(tester);
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('✎ Ghi chép tự do'), findsOneWidget);
    expect(find.text('Số tiền'), findsOneWidget);
  });

  testWidgets('widget tree contains expected structure', (tester) async {
    await pumpUntilLoaded(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
                ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
              ],
              child: const CustomInputWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('✎ Ghi chép tự do'), findsOneWidget);
    expect(find.text('Số tiền'), findsOneWidget);
    expect(find.text('Ghi chú (tùy chọn)'), findsOneWidget);
    expect(find.text('Thêm giao dịch'), findsOneWidget);
  });

  testWidgets('ExpenseViewModel.allTransactions feeds the engine',
      (tester) async {
    final txs = [
      Transaction(
        id: '1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'cơm trưa',
      ),
      Transaction(
        id: '2',
        amount: 35000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 6),
        note: 'cf sáng',
      ),
    ];
    when(() => mockDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);

    expenseVM = ExpenseViewModel(mockDs, mockExport, mockCategoryDS);
    await tester.pump();
    await tester.pump();

    expect(expenseVM.allTransactions.length, 2);

    final engine = TransactionSuggestionEngine();
    final anNgoai = seedCategories.firstWhere((c) => c.name == 'Ăn ngoài');
    final amounts = engine.getSuggestedAmounts(anNgoai, expenseVM.allTransactions);
    final notes = engine.getSuggestedNotes(anNgoai, expenseVM.allTransactions);

    expect(amounts, [50000]); // Ăn ngoài: median = 50k
    expect(notes, ['cơm trưa']);
  });

  // --- Focused interaction tests (ADR-0020 code-quality review) ---

  testWidgets(
      'selecting category shows amount + note suggestion chips',
      (tester) async {
    _useLargeSurface(tester);
    final txs = [
      Transaction(
        id: '1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'cơm trưa',
      ),
      Transaction(
        id: '2',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 6),
        note: 'phở',
      ),
    ];
    when(() => mockDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);

    await pumpUntilLoaded(tester);
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('Gợi ý số tiền'), findsNothing);

    await selectCategory(tester, 'Ăn ngoài');

    // Section headers + chip labels render
    expect(find.text('Gợi ý số tiền'), findsOneWidget);
    expect(find.text('Gợi ý ghi chú'), findsOneWidget);
    expect(find.text('50.000'), findsOneWidget); // formatted amount
    expect(find.text('phở'), findsOneWidget); // most recent note first
  });

  testWidgets('tapping amount chip fills amount field', (tester) async {
    _useLargeSurface(tester);
    final txs = [
      Transaction(
        id: '1',
        amount: 75000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 7),
        note: 'cf sáng',
      ),
    ];
    when(() => mockDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);

    await pumpUntilLoaded(tester);
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    await selectCategory(tester, 'Cà phê');

    // Tap amount chip
    await tester.tap(find.text('75.000'));
    await tester.pumpAndSettle();

    // Verify the TextField controller was updated with formatted value
    final amountFinder = find.widgetWithText(TextField, '75.000');
    expect(amountFinder, findsOneWidget);
  });

  testWidgets('tapping note chip fills note field', (tester) async {
    _useLargeSurface(tester);
    final txs = [
      Transaction(
        id: '1',
        amount: 30000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'bún chả',
      ),
    ];
    when(() => mockDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);

    await pumpUntilLoaded(tester);
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    await selectCategory(tester, 'Ăn ngoài');

    // Tap note chip
    await tester.tap(find.text('bún chả'));
    await tester.pumpAndSettle();

    final noteFinder = find.widgetWithText(TextField, 'bún chả');
    expect(noteFinder, findsOneWidget);
  });
}
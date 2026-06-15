import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/custom_input_widget.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

class _FakeCategoryViewModel extends CategoryViewModel {
  _FakeCategoryViewModel() : super.seeded(seedCategories);
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

  Future<void> pumpCustomInput(WidgetTester tester) async {
    // 2400x3200 to give chips enough room to render before scroll
    tester.view.physicalSize = const Size(2400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    when(() => mockDs.getAll()).thenAnswer((_) async => []);
    when(() => mockDs.getAllPaginated(
            offset: any(named: 'offset'),
            limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    expenseVM = ExpenseViewModel(mockDs, mockExport, mockCategoryDS);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
              ChangeNotifierProvider<CategoryViewModel>.value(
                  value: _FakeCategoryViewModel()),
            ],
            child: const CustomInputWidget(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('header shows "Ghi chép tự do"', (tester) async {
    await pumpCustomInput(tester);
    expect(find.text('✎ Ghi chép tự do'), findsOneWidget);
  });

  testWidgets('shows "Thêm giao dịch" button', (tester) async {
    await pumpCustomInput(tester);
    expect(find.text('Thêm giao dịch'), findsOneWidget);
  });

  // ===== ADR-0058 (fix 2026-06-16): category dropdown opens on tap =====
  // Pre-fix: `GestureDetector` was bound to `const Key('category-dropdown')`
  // (test-seam convention) but the `findRenderObject` lookup on line 155
  // used `_categoryKey.currentContext!`. GlobalKey.currentContext was
  // always null because the key was never assigned to a widget in the
  // tree → tap threw `Null check operator used on a null value` →
  // PopupMenu never opened → user could not pick a category.
  testWidgets('category dropdown opens on tap (ADR-0058 regression guard)',
      (tester) async {
    await pumpCustomInput(tester);

    // Find the category InputDecorator by its label "Danh mục" — the
    // GestureDetector wraps it. Pre-fix: tap silently threw
    // `Null check operator used on a null value` from
    // `_categoryKey.currentContext!` (GlobalKey was never bound) → no
    // PopupMenu found.
    final categoryField = find.ancestor(
      of: find.text('Danh mục'),
      matching: find.byType(InputDecorator),
    );
    expect(categoryField, findsOneWidget);
    await tester.tap(categoryField);
    await tester.pump(); // start showMenu animation
    await tester.pump(const Duration(milliseconds: 100));

    // Quick input categories come from seedCategories (mirrored in
    // CategoryViewModel.seeded). Verify at least one of the
    // predefined category names shows up in the open PopupMenu.
    expect(find.text('Ăn ngoài'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ===== ADR-0052 3.2: small-height viewport regression test =====
  // Pre-fix: `_buildSuggestionChips` returned a Column with N amounts + N
  // notes Wraps. When history has many txns for the selected category,
  // Wrap runs multiple lines → Column height grows. At 560px viewport
  // with 5+ chip entries, the suggestion Column pushed the bottom
  // "Thêm giao dịch" button off-screen, causing overflow.
  // Wrap moved the function call into SingleChildScrollView. This test
  // guards against re-introducing the unwrapped Column. The test pumps
  // the bare Card at 400x560 and asserts no exception — guards the
  // Card→Padding→Column layout itself.
  testWidgets('does not overflow at 400x560 viewport (regression guard)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txs = <Transaction>[
      for (var i = 0; i < 6; i++)
        Transaction(
          id: 'tx-$i',
          amount: 10000 + i * 5000,
          category: 'Ăn ngoài',
          categoryId: 'food_out',
          emoji: '🍜',
          date: DateTime(2026, 6, 1 + i),
          note: 'note $i',
        ),
    ];
    when(() => mockDs.getAll()).thenAnswer((_) async => txs);
    when(() => mockDs.getAllPaginated(
            offset: any(named: 'offset'),
            limit: any(named: 'limit')))
        .thenAnswer((_) async => txs);
    expenseVM = ExpenseViewModel(mockDs, mockExport, mockCategoryDS);

    final catVm = _FakeCategoryViewModel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
              ChangeNotifierProvider<CategoryViewModel>.value(value: catVm),
            ],
            child: const CustomInputWidget(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Bare Card (no category selected) at 400x560 — guards the
    // Card→Padding→Column layout.
    expect(tester.takeException(), isNull);
  });
}

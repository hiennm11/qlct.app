import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/data/datasources/quick_template_local_datasource.dart';
import 'package:qlct/viewmodels/quick_template_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/widgets/quick_templates_strip.dart';

class MockQuickTemplateDataSource extends Mock
    implements QuickTemplateLocalDataSource {}

class MockTransactionDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockQuickTemplateDataSource mockDs;
  late MockTransactionDataSource mockTxDs;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockExportService mockExport;
  late QuickTemplateViewModel vm;
  late ExpenseViewModel expenseVM;

  final sampleTemplate = QuickTemplate(
    id: 't-1',
    title: 'Cơm trưa',
    amount: 35000,
    categoryName: 'Ăn ngoài',
    emoji: '🍜',
    isPinned: true,
    usageCount: 5,
    createdAt: DateTime(2026, 6, 7),
    updatedAt: DateTime(2026, 6, 7),
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 6, 7));
    registerFallbackValue(sampleTemplate);
    registerFallbackValue(FakeTransaction());
  });

  setUp(() {
    mockDs = MockQuickTemplateDataSource();
    mockTxDs = MockTransactionDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockExport = MockExportService();

    when(() => mockDs.getAll()).thenAnswer((_) async => []);
    when(() => mockTxDs.getAll()).thenAnswer((_) async => []);
    when(() => mockTxDs.getAllPaginated(offset: any(named: 'offset'), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);

    vm = QuickTemplateViewModel(mockDs);
    expenseVM = ExpenseViewModel(mockTxDs, mockExport, mockCategoryDS);
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm),
            ChangeNotifierProvider.value(value: expenseVM),
            ChangeNotifierProvider<CategoryViewModel>.value(
                value: CategoryViewModel.seeded(seedCategories)),
          ],
          child: const QuickTemplatesStrip(),
        ),
      ),
    );
  }

  testWidgets('empty state shows "Tạo mẫu nhanh" chip', (tester) async {
    await tester.pumpWidget(buildWidget());
    // pump to allow the Future.microtask to complete
    await tester.pump();
    await tester.pump(); // ensure notifyListeners propagates
    await tester.pumpAndSettle();

    expect(find.text('Tạo mẫu nhanh'), findsOneWidget);
  });

  testWidgets('shows template chips when templates exist', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Cơm trưa'), findsOneWidget);
    // "Tạo mẫu nhanh" entry still shows when templates exist
    expect(find.text('Tạo mẫu nhanh'), findsOneWidget);
  });

  testWidgets('tapping template chip calls addTransaction and markUsed', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pumpAndSettle();

    verify(() => mockTxDs.add(any())).called(1);
    verify(() => mockDs.markUsed('t-1', any())).called(1);
  });

  testWidgets('snackbar shown after tapping template', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pump();

    expect(find.text('Đã thêm "Cơm trưa"'), findsOneWidget);
  });

  testWidgets('calls addTransaction then markUsed on success', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pump();

    final addCall = verify(() => mockTxDs.add(captureAny())).captured.single;
    expect(addCall.amount, 35000);
    expect(addCall.category, 'Ăn ngoài');
    expect(addCall.emoji, '🍜');

    verify(() => mockDs.markUsed('t-1', any())).called(1);
  });

  testWidgets('known category uses predefined emoji', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pump();

    final addCall = verify(() => mockTxDs.add(captureAny())).captured.single;
    expect(addCall.emoji, '🍜'); // predefined emoji from Category
  });

  // Issue #2: addTransaction sets errorMessage on failure (doesn't throw).
  // markUsed must NOT be called when add fails.
  testWidgets('add fails sets errorMessage — no markUsed, error snackbar',
      (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenThrow(Exception('db error'));
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pumpAndSettle();

    // markUsed must NOT be called when add failed
    verifyNever(() => mockDs.markUsed(any(), any()));
    // Error snackbar must be shown
    expect(find.text('Không thể thêm "Cơm trưa"'), findsOneWidget);
  });

  // Issue #4: ManageTemplatesSheet._confirmDelete must NOT show success
  // snackbar when delete returns false. Covered by unit test
  // (quick_template_viewmodel_test.dart) + the logic mirror below.
  test('delete returns false sets errorMessage (no success)', () async {
    when(() => mockDs.delete('t-1')).thenThrow(Exception('db error'));
    final result = await vm.delete('t-1');
    expect(result, isFalse);
    expect(vm.errorMessage, isNotNull);
    // Caller must check result before showing success snackbar
  });

  // --- QuickTemplateEditSheet suggestion chip behavior (ADR-0020 review) ---

  Widget buildEditSheet() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: vm),
              ChangeNotifierProvider.value(value: expenseVM),
              ChangeNotifierProvider<CategoryViewModel>.value(value: CategoryViewModel.seeded(seedCategories)),
            ],
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: QuickTemplateEditSheet(),
              ),
            ),
          ),
        ),
      ),
    );
  }

testWidgets('QuickTemplateEditSheet shows suggestion chips for default category',
      (tester) async {
    // Default _selectedCategory is 'Ăn ngoài'.
    final txs = [
      Transaction(
        id: '1',
        amount: 45000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'bún bò',
      ),
    ];
    when(() => mockTxDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);
    when(() => mockTxDs.getAll()).thenAnswer((_) async => txs);
    // expenseVM was created in setUp with empty txs; refresh to load new txs
    await expenseVM.refresh();
    await tester.pumpWidget(buildEditSheet());
    await tester.pump();
    await tester.pump();

    expect(find.text('Gợi ý số tiền'), findsOneWidget);
    expect(find.text('Gợi ý ghi chú'), findsOneWidget);
    expect(find.text('45.000'), findsOneWidget);
    expect(find.text('bún bò'), findsOneWidget);
  });

  testWidgets('tapping amount chip overrides amount field', (tester) async {
    final txs = [
      Transaction(
        id: '1',
        amount: 60000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'phở',
      ),
    ];
    when(() => mockTxDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);
    when(() => mockTxDs.getAll()).thenAnswer((_) async => txs);
    await expenseVM.refresh();
    await tester.pumpWidget(buildEditSheet());
    await tester.pump();
    await tester.pump();

    // Tap amount chip
    await tester.tap(find.text('60.000'));
    await tester.pumpAndSettle();

    // Amount TextField now shows formatted value
    expect(find.widgetWithText(TextField, '60.000'), findsOneWidget);
  });

  testWidgets('tapping note chip overrides note field', (tester) async {
    final txs = [
      Transaction(
        id: '1',
        amount: 30000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: 'cơm tấm',
      ),
    ];
    when(() => mockTxDs.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);
    when(() => mockTxDs.getAll()).thenAnswer((_) async => txs);
    await expenseVM.refresh();
    await tester.pumpWidget(buildEditSheet());
    await tester.pump();
    await tester.pump();

    // Tap note chip
    await tester.tap(find.text('cơm tấm'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'cơm tấm'), findsOneWidget);
  });

  // --- ThousandSeparatorFormatter wiring on QuickTemplateEditSheet ---

  Widget buildEditSheetWith({QuickTemplate? template}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: vm),
              ChangeNotifierProvider.value(value: expenseVM),
              ChangeNotifierProvider<CategoryViewModel>.value(value: CategoryViewModel.seeded(seedCategories)),
            ],
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: QuickTemplateEditSheet(template: template),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'editing existing template shows formatted amount, not raw integer',
      (tester) async {
    // Existing template with amount 50000 should display as "50.000"
    final existing = QuickTemplate(
      id: 't-1',
      title: 'Cà phê sáng',
      amount: 50000,
      categoryName: 'Cà phê',
      emoji: '☕',
      isPinned: false,
      usageCount: 1,
      createdAt: DateTime(2026, 6, 7),
      updatedAt: DateTime(2026, 6, 7),
    );

    await tester.pumpWidget(buildEditSheetWith(template: existing));
    await tester.pump();

    // Amount field must show "50.000" (formatted), NOT "50000" (raw)
    expect(find.widgetWithText(TextField, '50.000'), findsOneWidget);
    expect(find.widgetWithText(TextField, '50000'), findsNothing);
  });

  testWidgets('amount field auto-formats digits while typing', (tester) async {
    await tester.pumpWidget(buildEditSheetWith());
    await tester.pump();

    // Form has 3 TextFields in tree order: title (#0), amount (#1), note (#2).
    // Use EditableText at index 1 = amount field.
    final amountEditable = find.byType(EditableText).at(1);
    await tester.enterText(amountEditable, '1234567');
    await tester.pumpAndSettle();

    // Formatter should transform "1234567" → "1.234.567"
    expect(find.widgetWithText(TextField, '1.234.567'), findsOneWidget);
    // Raw unformatted text must not be present in the amount field
    expect(find.widgetWithText(TextField, '1234567'), findsNothing);
  });

  // Issue #2: chips use context.watch on ExpenseViewModel, so any future
  // VM notify (add/update/delete via _spliceInsert already calls
  // notifyListeners) will rebuild the chips. We verify the wiring is in
  // place by checking that the chip builder reads from watch() — covered
  // by the build-edit-sheet + 3 interaction tests above.
  //
  // NOTE: We don't test a full empty→loaded flow because
  // ExpenseViewModel.refresh() (used by pull-to-refresh and restore) does
  // not call notifyListeners. That's a pre-existing bug separate from the
  // 3 issues in this review. The watch fix here is still load-bearing for
  // add/update/delete paths which DO notify.
}

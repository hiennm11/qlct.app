import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/recurring_edit_dialog.dart';

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
    expenseVM = ExpenseViewModel(mockDs, mockExport, mockCategoryDS);
  });

  /// Wrap any child in a [ChangeNotifierProvider] with the shared [expenseVM].
  Widget wrapWithProvider(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
            ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
          ],
          child: child,
        ),
      ),
    );
  }

  group('RecurringEditDialog - add mode', () {
    testWidgets('shows "Thêm" title when no existing rule', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      expect(find.text('Thêm giao dịch định kỳ'), findsOneWidget);
      expect(find.text('Cập nhật'), findsNothing);
    });

    testWidgets('shows "Bắt đầu:" label in add mode', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      expect(find.text('Bắt đầu: '), findsOneWidget);
      expect(find.text('Ngày chạy kế tiếp: '), findsNothing);
    });

    testWidgets('defaults category to first predefined', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, seedCategories.first.name);
    });

    testWidgets('amount field is empty in add mode', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      final amountField = find.widgetWithText(TextFormField, '');
      expect(amountField, findsWidgets);
    });

    testWidgets('frequency defaults to daily (Ngày selected)', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'daily'});
    });
  });

  group('RecurringEditDialog - edit mode', () {
    final existing = RecurringTransaction(
      id: 'edit-1',
      categoryName: 'Cà phê',
      amount: 50000,
      note: 'morning coffee',
      frequency: 'weekly',
      nextRunAt: DateTime(2026, 6, 15),
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

    testWidgets('shows "Sửa" title when existing rule provided', (tester) async {
      await tester.pumpWidget(wrapWithProvider(RecurringEditDialog(existing: existing)));
      expect(find.text('Sửa giao dịch định kỳ'), findsOneWidget);
      expect(find.text('Cập nhật'), findsOneWidget);
      expect(find.text('Thêm'), findsNothing);
    });

    testWidgets('pre-fills amount with formatted value', (tester) async {
      await tester.pumpWidget(wrapWithProvider(RecurringEditDialog(existing: existing)));
      expect(find.text('50.000'), findsOneWidget);
    });

    testWidgets('pre-fills note', (tester) async {
      await tester.pumpWidget(wrapWithProvider(RecurringEditDialog(existing: existing)));
      expect(find.text('morning coffee'), findsOneWidget);
    });

    testWidgets('pre-fills frequency to weekly', (tester) async {
      await tester.pumpWidget(wrapWithProvider(RecurringEditDialog(existing: existing)));
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'weekly'});
    });

    testWidgets('shows "Ngày chạy kế tiếp:" label in edit mode', (tester) async {
      await tester.pumpWidget(wrapWithProvider(RecurringEditDialog(existing: existing)));
      expect(find.text('Ngày chạy kế tiếp: '), findsOneWidget);
      expect(find.text('Bắt đầu: '), findsNothing);
    });
  });

  group('RecurringEditDialog - category dropdown', () {
    testWidgets('contains all predefined categories', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      for (final c in seedCategories) {
        expect(find.text(c.name), findsAtLeastNWidgets(1));
      }
      expect(
        find.byType(DropdownMenuItem<String>),
        findsAtLeastNWidgets(seedCategories.length),
      );
    });
  });

  group('RecurringEditDialog - frequency segmented button', () {
    testWidgets('tapping weekly changes selection', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      await tester.tap(find.text('Tuần'));
      await tester.pump();
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'weekly'});
    });

    testWidgets('tapping monthly changes selection', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      await tester.tap(find.text('Tháng'));
      await tester.pump();
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'monthly'});
    });
  });

  group('RecurringEditDialog - amount validation', () {
    testWidgets('empty amount shows error', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      final addButton = find.widgetWithText(FilledButton, 'Thêm');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      expect(find.text('Vui lòng nhập số tiền'), findsOneWidget);
    });

    testWidgets('zero amount shows error', (tester) async {
      await tester.pumpWidget(wrapWithProvider(const RecurringEditDialog()));
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pump();
      expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
    });
  });

  group('RecurringEditDialog - save returns correct data', () {
    testWidgets('save with valid amount returns RecurringEditResult',
        (tester) async {
      RecurringEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
                ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
              ],
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await RecurringEditDialog.show(
                      context,
                      categoryViewModel: _FakeCategoryViewModel(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '100000');
      await tester.tap(find.text('Tuần'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.amount, 100000);
      expect(result!.frequency, 'weekly');
      expect(result!.id, isNull);
      expect(result!.categoryName, seedCategories.first.name);
    });

    testWidgets('save in edit mode returns existing id', (tester) async {
      final existing = RecurringTransaction(
        id: 'existing-xyz',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 10),
        createdAt: DateTime(2026, 6, 1),
      );
      RecurringEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
                ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
              ],
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await RecurringEditDialog.show(
                      context,
                      existing: existing,
                      categoryViewModel: _FakeCategoryViewModel(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cập nhật'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.id, 'existing-xyz');
      expect(result!.amount, 20000);
    });
  });

  group('RecurringEditDialog - cancel returns null', () {
    testWidgets('cancel button returns null', (tester) async {
      RecurringEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
                ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
              ],
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await RecurringEditDialog.show(
                      context,
                      categoryViewModel: _FakeCategoryViewModel(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Huỷ'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('tapping outside (barrier) returns null', (tester) async {
      RecurringEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<ExpenseViewModel>.value(value: expenseVM),
                ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
              ],
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await RecurringEditDialog.show(
                      context,
                      categoryViewModel: _FakeCategoryViewModel(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('RecurringEditDialog - suggestion chips', () {
    Future<void> pumpWithHistory(WidgetTester tester, List<Transaction> txs) async {
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
              child: RecurringEditDialog(
                expenseViewModel: expenseVM,
                categoryViewModel: _FakeCategoryViewModel(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('amount chip appears when history has matching transactions',
        (tester) async {
      final txs = [
        Transaction(
          id: 'h1',
          amount: 50000,
          category: 'Ăn ngoài',
          emoji: '🍜',
          date: DateTime(2026, 6, 5),
          note: '',
        ),
      ];
      await pumpWithHistory(tester, txs);
      expect(find.text('Gợi ý số tiền'), findsOneWidget);
      expect(find.text('50.000'), findsOneWidget);
    });

    testWidgets('tapping amount chip fills amount field', (tester) async {
      final txs = [
        Transaction(
          id: 'h1',
          amount: 50000,
          category: 'Ăn ngoài',
          emoji: '🍜',
          date: DateTime(2026, 6, 5),
          note: '',
        ),
      ];
      await pumpWithHistory(tester, txs);
      await tester.tap(find.text('50.000').first);
      await tester.pump();
      final amountField = find.byType(TextFormField).first;
      final textFormField = tester.widget<TextFormField>(amountField);
      expect(textFormField.controller?.text, '50.000');
    });

    testWidgets('note chip appears when history has matching notes',
        (tester) async {
      final txs = [
        Transaction(
          id: 'h1',
          amount: 50000,
          category: 'Cà phê',
          emoji: '☕',
          date: DateTime(2026, 6, 5),
          note: 'cf sáng',
        ),
      ];
      await pumpWithHistory(tester, txs);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cà phê').last);
      await tester.pumpAndSettle();
      expect(find.text('Gợi ý ghi chú'), findsOneWidget);
      expect(find.text('cf sáng'), findsOneWidget);
    });

    testWidgets('tapping note chip fills note field', (tester) async {
      final txs = [
        Transaction(
          id: 'h1',
          amount: 50000,
          category: 'Cà phê',
          emoji: '☕',
          date: DateTime(2026, 6, 5),
          note: 'cf sáng',
        ),
      ];
      await pumpWithHistory(tester, txs);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cà phê').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('cf sáng'));
      await tester.pump();
      final noteField = find.byType(TextFormField).last;
      final textFormField = tester.widget<TextFormField>(noteField);
      expect(textFormField.controller?.text, 'cf sáng');
    });

    testWidgets('no chips when no history', (tester) async {
      await pumpWithHistory(tester, []);
      expect(find.text('Gợi ý số tiền'), findsNothing);
      expect(find.text('Gợi ý ghi chú'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/transaction_edit_dialog.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

Transaction _tx({
  String id = 'tx-1',
  int amount = 50000,
  String category = 'Ăn ngoài',
  String emoji = '🍕',
  String note = 'Test note',
  String? sourceRecurringId,
  DateTime? date,
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    emoji: emoji,
    note: note,
    date: date ?? DateTime(2026, 6, 5),
    sourceRecurringId: sourceRecurringId,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('shows dialog with title "Sửa giao dịch"', (tester) async {
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showTransactionEditDialog(context, _tx()),
        child: const Text('Edit'),
      ),
    )));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Sửa giao dịch'), findsOneWidget);
  });


  testWidgets('shows recurring info label when sourceRecurringId set', (tester) async {
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showTransactionEditDialog(
          context,
          _tx(sourceRecurringId: 'rec-123'),
        ),
        child: const Text('Edit'),
      ),
    )));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(
      find.text('Giao dịch này được tạo tự động từ định kỳ'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.loop), findsOneWidget);
  });

  testWidgets('hides recurring info when sourceRecurringId is null', (tester) async {
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showTransactionEditDialog(context, _tx()),
        child: const Text('Edit'),
      ),
    )));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(
      find.text('Giao dịch này được tạo tự động từ định kỳ'),
      findsNothing,
    );
  });

  testWidgets('save returns updated transaction', (tester) async {
    Transaction? result;
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showTransactionEditDialog(context, _tx());
        },
        child: const Text('Edit'),
      ),
    )));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, 'tx-1');
  });

  group('TransactionEditDialog - suggestion chips', () {
    late MockTransactionLocalDataSource mockDs;
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
      mockExport = MockExportService();
      when(() => mockDs.getAll()).thenAnswer((_) async => []);
      when(() => mockDs.getAllPaginated(
 offset: any(named: 'offset'),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);
    });

    Future<void> pumpWithHistory(
      WidgetTester tester,
      List<Transaction> txs,
      Transaction txToEdit,
    ) async {
      when(() => mockDs.getAll()).thenAnswer((_) async => txs);
      when(() => mockDs.getAllPaginated(
              offset: any(named: 'offset'),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => txs);
      expenseVM = ExpenseViewModel(mockDs, mockExport);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ExpenseViewModel>.value(
              value: expenseVM,
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showTransactionEditDialog(context, txToEdit),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
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
      await pumpWithHistory(tester, txs, _tx(category: 'Ăn ngoài'));
      expect(find.text('Gợi ý số tiền'), findsOneWidget);
      // "50.000" appears in both chip and amount field (pre-filled).
      // Check that at least one ActionChip with "50.000" exists.
      expect(find.byType(ActionChip), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping amount chip overrides amount field', (tester) async {
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
      await pumpWithHistory(tester, txs, _tx(category: 'Ăn ngoài'));
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
      await pumpWithHistory(tester, txs, _tx(category: 'Cà phê'));
      expect(find.text('Gợi ý ghi chú'), findsOneWidget);
      expect(find.text('cf sáng'), findsOneWidget);
    });

    testWidgets('tapping note chip overrides note field', (tester) async {
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
      await pumpWithHistory(tester, txs, _tx(category: 'Cà phê'));
      await tester.tap(find.text('cf sáng').first);
      await tester.pump();
      final noteField = find.byType(TextFormField).last;
      final textFormField = tester.widget<TextFormField>(noteField);
      expect(textFormField.controller?.text, 'cf sáng');
    });

    testWidgets('current transaction is filtered out from suggestions',
        (tester) async {
      // Only the current transaction exists for this category.
      // It should NOT appear as a suggestion.
      final txs = [
        Transaction(
          id: 'tx-1',
          amount: 50000,
          category: 'Ăn ngoài',
          emoji: '🍜',
          date: DateTime(2026, 6, 5),
          note: 'only this one',
        ),
      ];
      await pumpWithHistory(tester, txs, _tx(id: 'tx-1', category: 'Ăn ngoài'));
      // No amount chip should appear since the only tx is the current one
      expect(find.text('Gợi ý số tiền'), findsNothing);
    });

    testWidgets('no chips when no history', (tester) async {
      await pumpWithHistory(tester, [], _tx());
      expect(find.text('Gợi ý số tiền'), findsNothing);
      expect(find.text('Gợi ý ghi chú'), findsNothing);
    });
  });
}

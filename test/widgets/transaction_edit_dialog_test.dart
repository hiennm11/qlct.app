import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/widgets/transaction_edit_dialog.dart';

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
}
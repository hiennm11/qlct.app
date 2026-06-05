import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/widgets/transaction_detail_sheet.dart';

Transaction _tx({
  String? id,
  int amount = 50000,
  String category = 'Ăn uống',
  String emoji = '🍕',
  String note = 'Cà phê sáng Highland',
  String? sourceRecurringId,
  DateTime? date,
}) {
  return Transaction(
    id: id ?? 'tx-1',
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
  testWidgets('renders emoji, category, amount, date', (tester) async {
    final tx = _tx();
    await tester.pumpWidget(_wrap(
      TransactionDetailSheet(transaction: tx),
    ));

    expect(find.text('🍕'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('-50.000\u00a0₫'), findsOneWidget);
    expect(find.text('Thứ Sáu, 05/06/2026'), findsOneWidget);
  });

  testWidgets('shows note when present, hides when empty', (tester) async {
    final withNote = _tx(note: 'Cà phê sáng Highland');
    await tester.pumpWidget(_wrap(TransactionDetailSheet(transaction: withNote)));
    expect(find.text('Cà phê sáng Highland'), findsOneWidget);
    expect(find.text('📝 Ghi chú:'), findsOneWidget);

    final noNote = _tx(note: '');
    await tester.pumpWidget(_wrap(TransactionDetailSheet(transaction: noNote)));
    expect(find.text('Cà phê sáng Highland'), findsNothing);
    expect(find.text('📝 Ghi chú:'), findsNothing);
  });

  testWidgets('shows recurring badge when sourceRecurringId != null', (tester) async {
    final tx = _tx(sourceRecurringId: 'rec-123');
    await tester.pumpWidget(_wrap(TransactionDetailSheet(transaction: tx)));
    expect(find.text('Từ giao dịch định kỳ'), findsOneWidget);
    expect(find.byIcon(Icons.loop), findsOneWidget);
  });

  testWidgets('hides recurring badge when sourceRecurringId == null', (tester) async {
    final tx = _tx();
    await tester.pumpWidget(_wrap(TransactionDetailSheet(transaction: tx)));
    expect(find.text('Từ giao dịch định kỳ'), findsNothing);
    expect(find.byIcon(Icons.loop), findsNothing);
  });

  testWidgets('onEdit callback fires on "Sửa" tap', (tester) async {
    var called = false;
    final tx = _tx();
    await tester.pumpWidget(_wrap(TransactionDetailSheet(
      transaction: tx,
      onEdit: () => called = true,
    )));
    await tester.tap(find.text('Sửa'));
    await tester.pump();
    expect(called, isTrue);
  });

  testWidgets('onDelete callback fires on "Xoá" tap', (tester) async {
    var called = false;
    final tx = _tx();
    await tester.pumpWidget(_wrap(TransactionDetailSheet(
      transaction: tx,
      onDelete: () => called = true,
    )));
    await tester.tap(find.text('Xoá'));
    await tester.pump();
    expect(called, isTrue);
  });
}

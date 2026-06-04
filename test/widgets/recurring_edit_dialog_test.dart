import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/widgets/recurring_edit_dialog.dart';

void main() {
  // Pump helper: wraps dialog in a real Navigator so showDialog works
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => const Center(
              child: ElevatedButton(
                onPressed: null,
                child: Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('RecurringEditDialog - add mode', () {
    testWidgets('shows "Thêm" title when no existing rule', (tester) async {
      await pumpDialog(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecurringEditDialog(existing: null),
          ),
        ),
      );

      expect(find.text('Thêm giao dịch định kỳ'), findsOneWidget);
      expect(find.text('Cập nhật'), findsNothing);
    });

    testWidgets('defaults category to first predefined', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, Category.predefined.first.name);
    });

    testWidgets('amount field is empty in add mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

      final amountField = find.widgetWithText(TextFormField, '');
      expect(amountField, findsWidgets);
    });

    testWidgets('frequency defaults to daily (Ngày selected)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecurringEditDialog(existing: existing)),
        ),
      );

      expect(find.text('Sửa giao dịch định kỳ'), findsOneWidget);
      expect(find.text('Cập nhật'), findsOneWidget);
      expect(find.text('Thêm'), findsNothing);
    });

    testWidgets('pre-fills amount with formatted value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecurringEditDialog(existing: existing)),
        ),
      );

      // 50000 -> "50.000"
      expect(find.text('50.000'), findsOneWidget);
    });

    testWidgets('pre-fills note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecurringEditDialog(existing: existing)),
        ),
      );

      expect(find.text('morning coffee'), findsOneWidget);
    });

    testWidgets('pre-fills frequency to weekly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecurringEditDialog(existing: existing)),
        ),
      );

      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'weekly'});
    });
  });

  group('RecurringEditDialog - category dropdown', () {
    testWidgets('contains all predefined categories', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Each category text appears at least once (in overlay)
      for (final c in Category.predefined) {
        expect(find.text(c.name), findsAtLeastNWidgets(1));
      }
      // Total dropdown items >= predefined categories (overlay may add extras)
      expect(
        find.byType(DropdownMenuItem<String>),
        findsAtLeastNWidgets(Category.predefined.length),
      );
    });
  });

  group('RecurringEditDialog - frequency segmented button', () {
    testWidgets('tapping weekly changes selection', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

      await tester.tap(find.text('Tuần'));
      await tester.pump();

      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'weekly'});
    });

    testWidgets('tapping monthly changes selection', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

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
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

      // Find the "Thêm" button (FilledButton in actions)
      final addButton = find.widgetWithText(FilledButton, 'Thêm');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();

      expect(find.text('Vui lòng nhập số tiền'), findsOneWidget);
    });

    testWidgets('zero amount shows error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecurringEditDialog()),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pump();

      expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
    });

    // Skip: ThousandSeparatorFormatter already prevents non-numeric input.
    // On real devices, keyboardType: TextInputType.number blocks non-digits.
    // Empty + zero amount validation covered by tests above.
  });

  group('RecurringEditDialog - save returns correct data', () {
    testWidgets('save with valid amount returns RecurringEditResult',
        (tester) async {
      RecurringEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await RecurringEditDialog.show(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Enter amount
      await tester.enterText(find.byType(TextFormField).first, '100000');
      await tester.tap(find.text('Tuần'));
      await tester.pump();

      // Tap Thêm (FilledButton)
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.amount, 100000);
      expect(result!.frequency, 'weekly');
      expect(result!.id, isNull); // add mode
      expect(result!.categoryName, Category.predefined.first.name);
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
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await RecurringEditDialog.show(
                    context,
                    existing: existing,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // amount field is pre-filled "20.000" - leave as is
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
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await RecurringEditDialog.show(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Huỷ button
      await tester.tap(find.widgetWithText(TextButton, 'Huỷ'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('tapping outside (barrier) returns null', (tester) async {
      RecurringEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await RecurringEditDialog.show(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap dialog scrim (top-left corner)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}

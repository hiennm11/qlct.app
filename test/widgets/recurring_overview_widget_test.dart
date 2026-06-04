import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/repositories/recurring_repository.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/widgets/recurring_overview_widget.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockRecurringRepository mockRecurringRepo;
  late MockTransactionRepository mockTransactionRepo;
  late RecurringTransactionViewModel vm;

  setUpAll(() {
    registerFallbackValue(RecurringTransaction(
      id: 'fb',
      categoryName: 'Cà phê',
      amount: 10000,
      nextRunAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
    ));
  });

  setUp(() {
    mockRecurringRepo = MockRecurringRepository();
    mockTransactionRepo = MockTransactionRepository();

    when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockTransactionRepo.getAll()).thenAnswer((_) async => []);

    vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: vm,
          child: const RecurringOverviewWidget(),
        ),
      ),
    );
  }

  group('RecurringOverviewWidget - empty state', () {
    testWidgets('shows empty message when no recurring rules', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.text('Chưa có giao dịch định kỳ nào. Nhấn + để thêm.'),
        findsOneWidget,
      );
    });

    testWidgets('does not show list tiles when empty', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('RecurringOverviewWidget - list display', () {
    final sampleRule1 = RecurringTransaction(
      id: 'rule-1',
      categoryName: 'Cà phê',
      amount: 20000,
      frequency: 'daily',
      nextRunAt: DateTime(2026, 6, 4),
      createdAt: DateTime(2026, 6, 1),
    );
    final sampleRule2 = RecurringTransaction(
      id: 'rule-2',
      categoryName: 'Ăn ngoài',
      amount: 50000,
      frequency: 'weekly',
      nextRunAt: DateTime(2026, 6, 5),
      createdAt: DateTime(2026, 6, 2),
    );

    testWidgets('shows list of recurring rules', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [sampleRule1, sampleRule2]);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.text('Ăn ngoài'), findsOneWidget);
    });

    testWidgets('shows frequency label "Hàng ngày" for daily', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [sampleRule1]);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Hàng ngày'), findsOneWidget);
    });

    testWidgets('shows frequency label "Hàng tuần" for weekly', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [sampleRule2]);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Hàng tuần'), findsOneWidget);
    });

    testWidgets('shows frequency label "Hàng tháng" for monthly', (tester) async {
      final monthlyRule = sampleRule1.copyWith(
        id: 'rule-monthly',
        categoryName: 'Subscription',
        amount: 200000,
        frequency: 'monthly',
      );
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [monthlyRule]);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Hàng tháng'), findsOneWidget);
    });

    testWidgets('limits display to maxDisplay (5) items', (tester) async {
      final rules = List.generate(
        7,
        (i) => RecurringTransaction(
          id: 'rule-$i',
          categoryName: 'Cà phê',
          amount: 20000,
          frequency: 'daily',
          nextRunAt: DateTime(2026, 6, 4),
          createdAt: DateTime(2026, 6, 1),
        ),
      );
      when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => rules);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(5));
      expect(find.text('Xem thêm 2 mục'), findsOneWidget);
    });
  });

  group('RecurringOverviewWidget - interactions', () {
    testWidgets('tapping + button shows add dialog', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Thêm giao dịch định kỳ'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Thêm'), findsOneWidget);
    });

    testWidgets('tapping a rule card shows edit dialog', (tester) async {
      final rule = RecurringTransaction(
        id: 'edit-rule',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 1),
      );
      when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => [rule]);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('Sửa giao dịch định kỳ'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Cập nhật'), findsOneWidget);
    });

    testWidgets('add dialog with data creates recurring rule', (tester) async {
      when(() => mockRecurringRepo.insert(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Enter amount
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '30000');
      await tester.pump();

      // Tap "Thêm"
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await tester.pumpAndSettle();

      // Verify insert was called
      verify(() => mockRecurringRepo.insert(any())).called(1);
    });

    testWidgets('toggle switch calls toggleActive', (tester) async {
      final rule = RecurringTransaction(
        id: 'switch-rule',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => [rule]);
      when(() => mockRecurringRepo.update(any())).thenAnswer((_) async {});
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await vm.toggleActive('switch-rule');
      await tester.pumpAndSettle();

      verify(() => mockRecurringRepo.update(any())).called(1);
    });

    testWidgets('dismissing card shows delete confirmation dialog',
        (tester) async {
      final rule = RecurringTransaction(
        id: 'delete-rule',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 1),
      );
      when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => [rule]);
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Dismissible), const Offset(-1000, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Xóa định kỳ?'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);
    });
  });

  group('RecurringOverviewWidget - header', () {
    testWidgets('shows header with title and add button', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('📅 Giao dịch định kỳ'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}

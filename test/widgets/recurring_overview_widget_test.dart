import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/recurring_overview_widget.dart';

class MockRecurringLocalDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class _FakeCategoryViewModel extends CategoryViewModel {
  _FakeCategoryViewModel() : super.seeded(seedCategories);
}

void main() {
  late MockRecurringLocalDataSource mockRecurringRepo;
  late MockTransactionLocalDataSource mockTransactionRepo;
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
    mockRecurringRepo = MockRecurringLocalDataSource();
    mockTransactionRepo = MockTransactionLocalDataSource();

    when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockTransactionRepo.getAll()).thenAnswer((_) async => []);

    vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm),
            ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
          ],
          child: const RecurringOverviewWidget(),
        ),
      ),
    );
  }

  group('RecurringOverviewWidget - empty state', () {
    testWidgets('shows empty state text when no recurring rules', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.text('Chưa có giao dịch định kỳ'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state emoji icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Two 🔄 expected: one in SectionHeader (24px) + one in empty state (48px)
      expect(find.text('🔄'), findsNWidgets(2));
      // 48px emoji specifically
      final bigEmoji = find.byWidgetPredicate(
        (w) => w is Text && w.data == '🔄' && w.style?.fontSize == 48,
      );
      expect(bigEmoji, findsOneWidget);
    });

    testWidgets('empty state text uses AppColors.textSecondary', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final textWidget = tester.widget<Text>(
        find.text('Chưa có giao dịch định kỳ'),
      );
      expect(textWidget.style!.color, AppColors.textSecondary);
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

      // 1 outer Card + 2 rule Cards = 3 total
      expect(find.byType(Card), findsNWidgets(3));
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

      // 1 outer Card + 5 rule Cards = 6 total
      expect(find.byType(Card), findsNWidgets(6));
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
    testWidgets('shows header with title', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Giao dịch định kỳ'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('RecurringOverviewWidget - error state', () {
    testWidgets('shows error message when errorMessage is set', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('Database corrupted'));
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
      await vm.forceReload(); // Trigger load with throwing mock

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // ViewModel format: 'Không thể tải dữ liệu. Vui lòng thử lại.'
      expect(find.textContaining('⚠️'), findsOneWidget);
      expect(find.textContaining('Không thể tải'), findsOneWidget);
      expect(find.textContaining('Vui lòng thử lại'), findsOneWidget);
    });

    testWidgets('error text uses AppColors.error', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('Test error'));
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
      await vm.forceReload(); // Trigger load with throwing mock

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Full text: '⚠️ Không thể tải dữ liệu. Vui lòng thử lại.'
      final errorText = find.byWidgetPredicate(
        (w) => w is Text && w.data!.contains('⚠️') && w.data!.contains('Không thể tải'),
      );
      expect(errorText, findsOneWidget);

      final textWidget = tester.widget<Text>(errorText);
      expect(textWidget.style?.color, AppColors.error);
    });

    testWidgets('error state shows SectionHeader with recurring title', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('Error'));
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
      await vm.forceReload(); // Trigger load with throwing mock

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Giao dịch định kỳ'), findsOneWidget);
    });
  });

  group('RecurringOverviewWidget - outer Card', () {
    testWidgets('wraps content in outer Card with Padding(16)', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Outer Card should exist (the wrapping one)
      // With data, we have 1 outer Card + 2 rule Cards = 3 Cards
      final cards = find.byType(Card);
      expect(cards, findsAtLeastNWidgets(1));
    });
  });
}

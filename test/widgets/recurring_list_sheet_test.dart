import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/widgets/recurring_list_sheet.dart';

class MockRecurringLocalDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

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
        body: ChangeNotifierProvider<RecurringTransactionViewModel>.value(
          value: vm,
          child: const RecurringListSheet(),
        ),
      ),
    );
  }

  group('RecurringListSheet - empty state', () {
    testWidgets('shows empty state text when no recurring rules', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.text('Chưa có giao dịch định kỳ nào'),
        findsOneWidget,
      );
    });

    testWidgets('empty state text uses AppColors.textSecondary', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final textWidget = tester.widget<Text>(
        find.text('Chưa có giao dịch định kỳ nào'),
      );
      expect(textWidget.style!.color, AppColors.textSecondary);
    });

    testWidgets('shows empty state emoji', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.text('📋'), findsOneWidget);
    });
  });

  group('RecurringListSheet - error state', () {
    testWidgets('shows error message when errorMessage is set', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('DB read failed'));
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

    testWidgets('error state hides empty state', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('Error'));
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
      await vm.forceReload(); // Trigger load with throwing mock

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Empty state should NOT be shown when error present
      expect(find.text('Chưa có giao dịch định kỳ nào'), findsNothing);
      expect(find.text('📋'), findsNothing);
    });

    testWidgets('error text is centered with padding', (tester) async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('Center test'));
      vm = RecurringTransactionViewModel(mockRecurringRepo, mockTransactionRepo);
      await vm.forceReload(); // Trigger load with throwing mock

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final errorText = find.byWidgetPredicate(
        (w) => w is Text && w.data!.contains('⚠️'),
      );
      final textWidget = tester.widget<Text>(errorText);
      expect(textWidget.textAlign, TextAlign.center);
    });
  });
}
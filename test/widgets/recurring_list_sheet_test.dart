import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/repositories/recurring_repository.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/widgets/recurring_list_sheet.dart';

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
}
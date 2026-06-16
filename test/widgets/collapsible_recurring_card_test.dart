import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/widgets/collapsible_recurring_card.dart';
import 'package:qlct/widgets/recurring_overview_widget.dart';

class MockRecurringLocalDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class _FakeCategoryViewModel extends CategoryViewModel {
  _FakeCategoryViewModel() : super.seeded(seedCategories);
}

void main() {
  late MockRecurringLocalDataSource mockRecurringRepo;
  late MockTransactionLocalDataSource mockTransactionRepo;
  late MockCategoryLocalDataSource mockCategoryDS;
  late RecurringTransactionViewModel vm;

  setUpAll(() {
    registerFallbackValue(RecurringTransaction(
      id: 'fb',
      categoryName: 'Cà phê',
      categoryId: 'coffee',
      amount: 10000,
      nextRunAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
    ));
  });

  setUp(() {
    mockRecurringRepo = MockRecurringLocalDataSource();
    mockTransactionRepo = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();

    when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);

    vm = RecurringTransactionViewModel(
      mockRecurringRepo,
      mockTransactionRepo,
      mockCategoryDS,
    );
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<RecurringTransactionViewModel>.value(value: vm),
            ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
          ],
          child: child,
        ),
      ),
    );
  }

  group('ADR-0080 CollapsibleRecurringCard', () {
    testWidgets('mặc định hiển thị header "Giao dịch định kỳ" với chevron xuống',
        (tester) async {
      await tester.pumpWidget(wrap(const CollapsibleRecurringCard()));
      await tester.pumpAndSettle();

      expect(find.text('Giao dịch định kỳ'), findsOneWidget);
      expect(find.byKey(const Key('recurring-collapse-header')), findsOneWidget);
      // RecurringOverviewWidget bị ẩn khi collapsed.
      expect(find.byType(RecurringOverviewWidget), findsNothing);
    });

    testWidgets('tap header expand → RecurringOverviewWidget render', (tester) async {
      await tester.pumpWidget(wrap(const CollapsibleRecurringCard()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurring-collapse-header')));
      await tester.pumpAndSettle();

      expect(find.byType(RecurringOverviewWidget), findsOneWidget);
    });

    testWidgets('expand với rule list hiển thị category', (tester) async {
      when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => [
            RecurringTransaction(
              id: 'r-1',
              categoryName: 'Cà phê',
              categoryId: 'coffee',
              amount: 50000,
              note: '',
              frequency: 'daily',
              nextRunAt: DateTime.now().add(const Duration(days: 1)),
              isActive: true,
              createdAt: DateTime.now(),
            ),
          ]);
      // Reconstruct VM AFTER mock setup — VM ctor fires initial load
      // microtask, so cần mock ready trước khi construct.
      vm = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTransactionRepo,
        mockCategoryDS,
      );

      await tester.pumpWidget(wrap(const CollapsibleRecurringCard()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurring-collapse-header')));
      await tester.pumpAndSettle();

      expect(find.text('Cà phê'), findsOneWidget);
    });
  });
}

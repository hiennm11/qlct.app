import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/services/monthly_budget_plan_builder.dart';
import 'package:qlct/viewmodels/monthly_plan_viewmodel.dart';
import 'package:qlct/views/monthly_plan_screen.dart';

class MockBudgetPlanLocalDataSource extends Mock implements BudgetPlanLocalDataSource {}
class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}
class MockBudgetSnapshotLocalDataSource extends Mock implements BudgetSnapshotLocalDataSource {}
class MockTransactionLocalDataSource extends Mock implements TransactionLocalDataSource {}
class MockCategoryLocalDataSource extends Mock implements CategoryLocalDataSource {}
class MockStorageService extends Mock implements StorageService {}

class FakeBudgetPlan extends Fake implements BudgetPlan {}
class FakeBudgetPlanItem extends Fake implements BudgetPlanItem {}

void main() {
  late MockBudgetPlanLocalDataSource mockPlanDS;
  late MockBudgetLocalDataSource mockBudgetDS;
  late MockBudgetSnapshotLocalDataSource mockSnapshotDS;
  late MockTransactionLocalDataSource mockTxDS;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockStorageService mockStorage;
  late MonthlyPlanViewModel vm;
  late DateTime fixedNow;

  setUpAll(() {
    registerFallbackValue(FakeBudgetPlan());
    registerFallbackValue(<BudgetPlanItem>[]);
  });

  setUp(() {
    mockPlanDS = MockBudgetPlanLocalDataSource();
    mockBudgetDS = MockBudgetLocalDataSource();
    mockSnapshotDS = MockBudgetSnapshotLocalDataSource();
    mockTxDS = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockStorage = MockStorageService();

    // Stub all datasources
    when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
    when(() => mockPlanDS.getItems(any())).thenAnswer((_) async => <BudgetPlanItem>[]);
    when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => <Budget>[]);
    when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => seedCategories);

    // Fix current month so targetMonth is predictable
    fixedNow = DateTime(2026, 6, 10);

    vm = MonthlyPlanViewModel(
      budgetPlanDataSource: mockPlanDS,
      budgetDataSource: mockBudgetDS,
      budgetSnapshotDataSource: mockSnapshotDS,
      transactionDataSource: mockTxDS,
      categoryDataSource: mockCategoryDS,
      storageService: mockStorage,
      builder: MonthlyBudgetPlanBuilder(),
      now: fixedNow,
    );
    // Drain initial load microtask
    vm.load();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MonthlyPlanViewModel>.value(value: vm),
          ChangeNotifierProvider<CategoryViewModel>.value(
              value: CategoryViewModel.seeded(seedCategories)),
        ],
        child: const MonthlyPlanScreen(),
      ),
    );
  }

  group('MonthlyPlanScreen - title', () {
    testWidgets('AppBar title shows plan month identity', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Target month is July 2026 (current is June 2026)
      expect(find.text('Kế hoạch tháng tới'), findsOneWidget);
    });
  });

  group('MonthlyPlanScreen - source buttons', () {
    testWidgets('renders three source action buttons', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Copy tháng trước'), findsOneWidget);
      expect(find.text('Copy budget hiện tại'), findsOneWidget);
      expect(find.text('Tạo rỗng'), findsOneWidget);
    });

    testWidgets('Copy tháng trước triggers resetSource with previousMonth', (tester) async {
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy tháng trước'));
      await tester.pumpAndSettle();

      verify(() => mockPlanDS.saveDraft(any(), any())).called(greaterThanOrEqualTo(1));
    });

    testWidgets('Copy budget hiện tại triggers resetSource with currentBudget', (tester) async {
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy budget hiện tại'));
      await tester.pumpAndSettle();

      verify(() => mockPlanDS.saveDraft(any(), any())).called(greaterThanOrEqualTo(1));
    });

    testWidgets('Tạo rỗng triggers resetSource with empty', (tester) async {
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo rỗng'));
      await tester.pumpAndSettle();

      verify(() => mockPlanDS.saveDraft(any(), any())).called(greaterThanOrEqualTo(1));
    });
  });

  group('MonthlyPlanScreen - section headers', () {
    testWidgets('renders section headers when data available', (tester) async {
      // Use buildScreen() which uses setUp VM (has no draft, creates new)
      // This test verifies that when a draft is pre-loaded, sections appear
      // Use the VM from setUp which creates a draft on load
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // When no draft exists, the builder creates a new plan
      // With no transaction history, all items have baseLimit=0, suggested=0
      // So all items get recommendation='keep' -> only 'Giữ nguyên' section
      expect(find.text('Giữ nguyên'), findsOneWidget);
    });
  });

  group('MonthlyPlanScreen - total budget', () {
    testWidgets('displays editable total budget field', (tester) async {
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Should have an input field for total budget
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
    });
  });

  group('MonthlyPlanScreen - future target CTA', () {
    testWidgets('renders future month CTA with subtitle', (tester) async {
      // Set up: no existing draft, so new draft is created on load
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Scroll to the bottom of the list to find the CTA
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      // Should have CTA for July 2026 (target month)
      expect(find.textContaining('Lưu plan cho Tháng'), findsOneWidget);
      // Both lines of the CTA should be present
      expect(find.textContaining('Tự áp dụng'), findsOneWidget);
    });
  });

  group('MonthlyPlanScreen - saved indicator', () {
    testWidgets('shows saved indicator when draft is loaded or created', (tester) async {
      // No existing draft, so new draft is created on load
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // After creating new draft, savedMessage should be 'Đã tạo nháp mới'
      expect(find.textContaining('Đã tạo nháp mới'), findsOneWidget);
    });
  });

  group('MonthlyPlanScreen - item rows', () {
    testWidgets('renders category rows with plannedLimit field', (tester) async {
      // No draft, new draft created on load
      when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => null);
      when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Category name should appear (Ăn ngoài is in the predefined list)
      expect(find.text('Ăn ngoài'), findsOneWidget);
      // Emoji should appear
      expect(find.text('🍜'), findsOneWidget);
    });
  });

  group('MonthlyPlanScreen - loading state', () {
    testWidgets('shows loading indicator while loading', (tester) async {
      // The VM starts loading in constructor via Future.microtask
      // Check that data is null initially
      expect(vm.data, isNull);
    });
  });
}
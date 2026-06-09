import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/widgets/budget_overview_widget.dart';
import 'package:qlct/widgets/section_header.dart';

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockBudgetSnapshotLocalDataSource extends Mock
    implements BudgetSnapshotLocalDataSource {}

class MockBudgetPlanDataSource extends Mock
    implements BudgetPlanLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

class FakeBudgetSnapshot extends Fake implements BudgetSnapshot {}

void main() {
  late MockBudgetLocalDataSource mockRepo;
  late MockBudgetSnapshotLocalDataSource mockSnapshotRepo;
  late MockBudgetPlanDataSource mockPlanRepo;
  late MockStorageService mockStorage;
  late BudgetViewModel vm;

  setUpAll(() {
    registerFallbackValue(Budget(
      id: '0',
      categoryName: '',
      monthlyLimit: 0,
      alertThreshold: 80,
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(FakeBudgetSnapshot());
    registerFallbackValue(BudgetPlan(
      yearMonth: '2026-01',
      plannedTotalBudget: 0,
      source: 'test',
      status: 'draft',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    registerFallbackValue(BudgetPlanItem(
      yearMonth: '2026-01',
      categoryName: 'test',
      plannedLimit: 0,
    ));
  });

  setUp(() {
    mockRepo = MockBudgetLocalDataSource();
    mockSnapshotRepo = MockBudgetSnapshotLocalDataSource();
    mockPlanRepo = MockBudgetPlanDataSource();
    mockStorage = MockStorageService();
    // BudgetLocalDataSource stubs
    when(() => mockRepo.getAll()).thenAnswer((_) async => <Budget>[]);
    when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => null);
    when(() => mockRepo.bulkUpsert(any())).thenAnswer((_) async {});
    when(() => mockRepo.clearAll()).thenAnswer((_) async {});
    when(() => mockRepo.count()).thenAnswer((_) async => 0);
    // BudgetSnapshotLocalDataSource stubs
    when(() => mockSnapshotRepo.getAll()).thenAnswer((_) async => <BudgetSnapshot>[]);
    when(() => mockSnapshotRepo.getByYearMonth(any())).thenAnswer((_) async => <BudgetSnapshot>[]);
    when(() => mockSnapshotRepo.bulkUpsert(any())).thenAnswer((_) async {});
    // BudgetPlanLocalDataSource stubs (ADR-0026)
    when(() => mockPlanRepo.getPlan(any())).thenAnswer((_) async => null);
    when(() => mockPlanRepo.getItems(any())).thenAnswer((_) async => <BudgetPlanItem>[]);
    when(() => mockPlanRepo.getDraft(any())).thenAnswer((_) async => null);
    when(() => mockPlanRepo.upsertPlan(any())).thenAnswer((_) async {});
    when(() => mockPlanRepo.bulkUpsertItems(any())).thenAnswer((_) async {});
    when(() => mockPlanRepo.saveDraft(any(), any())).thenAnswer((_) async {});
    when(() => mockPlanRepo.markApplied(any(), any())).thenAnswer((_) async {});
    when(() => mockPlanRepo.delete(any())).thenAnswer((_) async {});
    when(() => mockPlanRepo.clearAll()).thenAnswer((_) async {});
    when(() => mockPlanRepo.getAllPlans()).thenAnswer((_) async => <BudgetPlan>[]);
    when(() => mockPlanRepo.getAllItems()).thenAnswer((_) async => <BudgetPlanItem>[]);
    when(() => mockPlanRepo.count()).thenAnswer((_) async => 0);
    when(() => mockPlanRepo.itemCount()).thenAnswer((_) async => 0);
    // StorageService stubs
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    // Pre-load so _loadBudgetsFuture resolves before any test body runs.
    // This ensures pumpWidget() in the first two tests sees a settled VM.
    vm = BudgetViewModel(mockRepo, mockSnapshotRepo, mockPlanRepo, mockStorage);
    // Wait for constructor's Future.microtask to complete so _loadBudgetsImpl
    // finishes before test body starts. This prevents pumpAndSettle timeout.
    vm.forceReload(); // fire and forget — _loadBudgetsFuture now resolves async
  });

  Widget wrap() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: vm,
          child: const BudgetOverviewWidget(),
        ),
      ),
    );
  }

  List<Budget> mixedBudgets() => [
        Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 2000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 1, 1),
        ),
        Budget(
          id: '2',
          categoryName: 'Cà phê',
          monthlyLimit: 1000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 1, 1),
        ),
        Budget(
          id: '3',
          categoryName: 'Ăn nhà',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

  List<Budget> exceededBudgets() => [
        Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 2000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 1, 1),
        ),
        Budget(
          id: '2',
          categoryName: 'Cà phê',
          monthlyLimit: 1000000,
          alertThreshold: 80,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

  ExpenseStats buildStats(Map<String, int> categoryTotals) {
    return ExpenseStats(
      todayExpense: 0,
      weekExpense: 0,
      monthExpense: categoryTotals.values.fold(0, (a, b) => a + b),
      categoryTotals: categoryTotals,
    );
  }

  group('BudgetOverviewWidget - SectionHeader integration', () {
    testWidgets('renders SectionHeader with emoji, title and edit action',
        (tester) async {
      // Constructor's _loadBudgets microtask already completed in setUp.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('💼'), findsOneWidget);
      expect(find.text('Ngân sách tháng'), findsOneWidget);
      final header = tester.widget<SectionHeader>(find.byType(SectionHeader));
      expect(header.actionIcon, Icons.edit);
      expect(header.onAction, isNotNull);
    });

    testWidgets('renders entry point button Lên kế hoạch tháng tới (ADR-0026)',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Lên kế hoạch tháng tới'), findsOneWidget);
    });

    testWidgets('action button is tappable', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final headerFinder = find.byType(SectionHeader);
      expect(
        find.descendant(of: headerFinder, matching: find.byIcon(Icons.edit)),
        findsOneWidget,
      );
    });
  });

  group('BudgetOverviewWidget - ADR-0014 alert-first display', () {
    group('with mixed budgets (exceeded + warning + normal)', () {
      testWidgets('alert cards (warning + exceeded) visible by default',
          (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => mixedBudgets());
        await vm.forceReload();
        vm.updateStats(buildStats({
          'Ăn ngoài': 2500000, // 125% exceeded
          'Cà phê': 900000,    // 90% warning
          'Ăn nhà': 500000,    // 10% normal
        }));
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Ăn ngoài'), findsOneWidget);
        expect(find.text('Cà phê'), findsOneWidget);
      });

      testWidgets('normal cards NOT visible by default', (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => mixedBudgets());
        await vm.forceReload();
        vm.updateStats(buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Ăn nhà'), findsNothing);
      });

      testWidgets('"Xem tất cả" button visible when normal statuses exist',
          (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => mixedBudgets());
        await vm.forceReload();
        vm.updateStats(buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Xem tất cả 1 ngân sách khác'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets(
          'tap "Xem tất cả" -> normal cards appear, button becomes "Thu gọn"',
          (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => mixedBudgets());
        await vm.forceReload();
        vm.updateStats(buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Xem tất cả 1 ngân sách khác'));
        await tester.pumpAndSettle();

        expect(find.text('Ăn nhà'), findsOneWidget);
        expect(find.text('Thu gọn'), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        // Alert cards still visible
        expect(find.text('Ăn ngoài'), findsOneWidget);
        expect(find.text('Cà phê'), findsOneWidget);
      });

      testWidgets('tap "Thu gọn" -> normal cards hidden again', (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => mixedBudgets());
        await vm.forceReload();
        vm.updateStats(buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand
        await tester.tap(find.text('Xem tất cả 1 ngân sách khác'));
        await tester.pumpAndSettle();
        expect(find.text('Ăn nhà'), findsOneWidget);

        // Collapse
        await tester.tap(find.text('Thu gọn'));
        await tester.pumpAndSettle();

        expect(find.text('Ăn nhà'), findsNothing);
        expect(find.text('Xem tất cả 1 ngân sách khác'), findsOneWidget);
      });
    });

    group('with all-exceeded budgets (no normal)', () {
      testWidgets('no toggle button when no normal statuses', (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => exceededBudgets());
        await vm.forceReload();
        vm.updateStats(buildStats({
          'Ăn ngoài': 3000000, // 150% exceeded
          'Cà phê': 1200000,   // 120% exceeded
        }));
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Ăn ngoài'), findsOneWidget);
        expect(find.text('Cà phê'), findsOneWidget);
        expect(find.textContaining('Xem tất cả'), findsNothing);
        expect(find.textContaining('Thu gọn'), findsNothing);
        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(find.byIcon(Icons.expand_less), findsNothing);
      });
    });
  });

  group('BudgetOverviewWidget - ADR-0025 §6 investment exclusion', () {
    testWidgets('does not render investment category card even if budget exists',
        (tester) async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Budget(
              id: 'inv-1',
              categoryName: 'Đầu tư',
              monthlyLimit: 10000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
            Budget(
              id: 'food-1',
              categoryName: 'Ăn ngoài',
              monthlyLimit: 1000000,
              alertThreshold: 80,
              createdAt: DateTime(2026, 1, 1),
            ),
          ]);
      await vm.forceReload();
      // Make Ăn ngoài warning (90% of 1M = 900k) so it shows by default
      vm.updateStats(buildStats({
        'Đầu tư': 12000000, // exceeded but should be excluded
        'Ăn ngoài': 900000, // 90% warning — shows in default view
      }));
      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pumpAndSettle();

      // Ăn ngoài budget card should appear
      expect(find.text('Ăn ngoài'), findsOneWidget);
      // Đầu tư budget card should NOT appear
      expect(find.text('Đầu tư'), findsNothing,
          reason: 'Investment category should be excluded from budget overview');
    });
  });
}
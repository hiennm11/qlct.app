import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/expense_stats.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/widgets/budget_overview_widget.dart';
import 'package:qlct/widgets/section_header.dart';

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockBudgetLocalDataSource mockRepo;
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
  });

  setUp(() {
    mockRepo = MockBudgetLocalDataSource();
    mockStorage = MockStorageService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    vm = BudgetViewModel(mockRepo, mockStorage);
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

  List<Budget> _mixedBudgets() => [
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

  List<Budget> _exceededBudgets() => [
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

  ExpenseStats _buildStats(Map<String, int> categoryTotals) {
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
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('💼'), findsOneWidget);
      expect(find.text('Ngân sách tháng'), findsOneWidget);
      final header = tester.widget<SectionHeader>(find.byType(SectionHeader));
      expect(header.actionIcon, Icons.edit);
      expect(header.onAction, isNotNull);
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
        when(() => mockRepo.getAll()).thenAnswer((_) async => _mixedBudgets());
        await vm.forceReload();
        vm.updateStats(_buildStats({
          'Ăn ngoài': 2500000, // 125% exceeded
          'Cà phê': 900000,    // 90% warning
          'Ăn nhà': 500000,    // 10% normal
        }));
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.text('Ăn ngoài'), findsOneWidget);
        expect(find.text('Cà phê'), findsOneWidget);
      });

      testWidgets('normal cards NOT visible by default', (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => _mixedBudgets());
        await vm.forceReload();
        vm.updateStats(_buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.text('Ăn nhà'), findsNothing);
      });

      testWidgets('"Xem tất cả" button visible when normal statuses exist',
          (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => _mixedBudgets());
        await vm.forceReload();
        vm.updateStats(_buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.text('Xem tất cả 1 ngân sách khác'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets(
          'tap "Xem tất cả" -> normal cards appear, button becomes "Thu gọn"',
          (tester) async {
        when(() => mockRepo.getAll()).thenAnswer((_) async => _mixedBudgets());
        await vm.forceReload();
        vm.updateStats(_buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
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
        when(() => mockRepo.getAll()).thenAnswer((_) async => _mixedBudgets());
        await vm.forceReload();
        vm.updateStats(_buildStats({
          'Ăn ngoài': 2500000,
          'Cà phê': 900000,
          'Ăn nhà': 500000,
        }));
        await tester.pumpWidget(wrap());
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
        when(() => mockRepo.getAll()).thenAnswer((_) async => _exceededBudgets());
        await vm.forceReload();
        vm.updateStats(_buildStats({
          'Ăn ngoài': 3000000, // 150% exceeded
          'Cà phê': 1200000,   // 120% exceeded
        }));
        await tester.pumpWidget(wrap());
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
}
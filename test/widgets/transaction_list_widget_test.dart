import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/transaction_list_widget.dart';

/// In-memory fake repository — returns empty list by default.
class _FakeTransactionRepository implements TransactionRepository {
  @override
  Future<List<Transaction>> getAll() async => [];
  @override
  Future<void> add(Transaction t) async {}
  @override
  Future<void> update(Transaction t) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> clearAll() async {}
  @override
  Future<List<Transaction>> getByDate(DateTime date) async => [];
  @override
  Future<List<Transaction>> getByCategory(String category) async => [];
  @override
  Future<List<Transaction>> getByDateRange(DateTime s, DateTime e) async => [];
  @override
  Future<void> bulkAdd(List<Transaction> ts) async {}
  @override
  Future<List<Transaction>> search(String query) async => [];
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

/// Fake export service — extends concrete ExportService but stubs network calls.
class _FakeExportService extends ExportService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Return safe defaults for any ExportService method that the VM might invoke.
    final symbol = invocation.memberName;
    if (invocation.isMethod && symbol == #exportToCsv) {
      return Future.value('csv-stub');
    }
    if (invocation.isMethod && symbol == #exportToJson) {
      return Future.value('json-stub');
    }
    if (invocation.isMethod && symbol == #exportSelectedToCsv) {
      return Future.value();
    }
    if (invocation.isMethod && symbol == #shareFile) {
      return Future.value();
    }
    return super.noSuchMethod(invocation);
  }
}

Widget _wrap(ExpenseViewModel vm) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: ChangeNotifierProvider<ExpenseViewModel>.value(
      value: vm,
      child: const Scaffold(body: SingleChildScrollView(child: TransactionListWidget())),
    ),
  );
}

void main() {
  late ExpenseViewModel vm;

  setUp(() {
    vm = ExpenseViewModel(_FakeTransactionRepository(), _FakeExportService());
  });

  group('TransactionListWidget filter row', () {
    testWidgets('renders search field and three filter chips', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Tìm kiếm giao dịch...'), findsOneWidget);

      // All three filter chips
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Ngày'), findsOneWidget);
      expect(find.text('Danh mục'), findsOneWidget);
    });

    testWidgets('Today chip tap sets date filter to today', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      await tester.tap(find.text('Hôm nay'));
      await tester.pump();

      expect(vm.filterDate, isNotNull);
      final now = DateTime.now();
      expect(vm.filterDate!.year, now.year);
      expect(vm.filterDate!.month, now.month);
      expect(vm.filterDate!.day, now.day);
    });

    testWidgets('Today chip second tap clears the date filter', (tester) async {
      // Seed date = today so chip starts selected
      final today = DateTime.now();
      vm.setDateFilter(DateTime(today.year, today.month, today.day));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      await tester.tap(find.text('Hôm nay'));
      await tester.pump();

      expect(vm.filterDate, isNull);
    });

    testWidgets('Today chip shows selected state when date == today', (tester) async {
      final today = DateTime.now();
      vm.setDateFilter(DateTime(today.year, today.month, today.day));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      // ActionChip wrapping "Hôm nay" should be selected
      final chip = tester.widget<ActionChip>(find.ancestor(
        of: find.text('Hôm nay'),
        matching: find.byType(ActionChip),
      ));
      expect(chip.backgroundColor, isNotNull); // selected chips have a colored bg
    });

    testWidgets('Date chip opens date picker on tap', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      await tester.tap(find.text('Ngày'));
      await tester.pump();

      // Material date picker dialog shows "OK" and "Cancel" buttons
      expect(find.text('OK'), findsWidgets);
    });

    testWidgets('Date chip shows selected date in dd/MM format', (tester) async {
      vm.setDateFilter(DateTime(2026, 6, 5));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('05/06'), findsOneWidget);
    });

    testWidgets('Category chip shows category list popup on tap', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      await tester.tap(find.text('Danh mục'));
      await tester.pump();

      // PopupMenuButton shows a list; at minimum "Tất cả" + predefined categories
      expect(find.text('Tất cả'), findsOneWidget);
    });

    testWidgets('Category chip shows selected category label', (tester) async {
      vm.setCategoryFilter('Ăn ngoài');
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('🍜 Ăn ngoài'), findsOneWidget);
    });

    testWidgets('Clear chip is hidden when no filter is active', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('Xoá'), findsNothing);
    });

    testWidgets('Clear chip is visible when date filter is active', (tester) async {
      vm.setDateFilter(DateTime(2026, 6, 5));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('Xoá'), findsOneWidget);
    });

    testWidgets('Clear chip is visible when category filter is active', (tester) async {
      vm.setCategoryFilter('Ăn ngoài');
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('Xoá'), findsOneWidget);
    });

    testWidgets('Clear chip tap calls clearFilters and resets filters', (tester) async {
      vm.setDateFilter(DateTime(2026, 6, 5));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      await tester.tap(find.text('Xoá'));
      await tester.pump();

      expect(vm.filterDate, isNull);
      expect(vm.filterCategory, isNull);
    });

    testWidgets('Filter chips use Wrap layout (wraps on narrow screens)', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      // The filter row is inside a Wrap widget (chips wrap on small screens)
      expect(find.byType(Wrap), findsWidgets);
    });
  });
}
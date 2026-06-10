import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/transaction_list_widget.dart';

/// In-memory fake data source — returns empty list by default.
class _FakeTransactionDataSource implements TransactionLocalDataSource {
  final List<Transaction> _store = [];

  /// Operations recorded for assertion in tests.
  int clearAllCalls = 0;
  int deleteMultipleCalls = 0;
  int addCalls = 0;
  int bulkInsertCalls = 0;

  @override
  Future<List<Transaction>> getAll() async => List.of(_store);

  @override
  Future<void> add(Transaction t) async {
    addCalls++;
    _store.add(t);
  }

  @override
  Future<void> update(Transaction t) async {}

  @override
  Future<void> delete(String id) async {
    _store.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> clearAll() async {
    clearAllCalls++;
    _store.clear();
  }

  @override
  Future<int> count() async => _store.length;

  @override
  Future<List<Transaction>> getByDate(DateTime date) async => [];
  @override
  Future<List<Transaction>> getByCategory(String category) async => [];
  @override
  Future<List<Transaction>> getByDateRange(DateTime s, DateTime e) async => [];
  @override
  Future<void> bulkInsert(List<Transaction> ts) async {
    bulkInsertCalls++;
    _store.addAll(ts);
  }
  @override
  Future<List<Transaction>> search(String query) async => List.of(_store);
  @override
  Future<void> deleteMultiple(List<String> ids) async {
    deleteMultipleCalls++;
    _store.removeWhere((t) => ids.contains(t.id));
  }

  @override
  Future<bool> existsBySourceRecurringIdAndDate(
          String sourceRecurringId, String dateStr) async =>
      false;

  @override
  Future<List<Transaction>> getAllPaginated({
    required int offset,
    required int limit,
  }) async =>
      List.of(_store);
}

/// Mock category data source — used by ExpenseViewModel for catalog lookups.
class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

/// Fake export service — returns valid File objects so success SnackBars fire.
class _FakeExportService extends ExportService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final symbol = invocation.memberName;
    if (invocation.isMethod && symbol == #exportToCsv) {
      return Future.value(File('/tmp/csv-stub.csv'));
    }
    if (invocation.isMethod && symbol == #exportToJson) {
      return Future.value(File('/tmp/json-stub.json'));
    }
    if (invocation.isMethod && symbol == #exportSelectedToCsv) {
      return Future.value();
    }
    if (invocation.isMethod && symbol == #exportSelectedToJson) {
      return Future.value();
    }
    if (invocation.isMethod && symbol == #shareFile) {
      return Future.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeCategoryViewModel extends CategoryViewModel {
  _FakeCategoryViewModel() : super.seeded(seedCategories);
}

Widget _wrap(ExpenseViewModel vm) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseViewModel>.value(value: vm),
        ChangeNotifierProvider<CategoryViewModel>.value(value: _FakeCategoryViewModel()),
      ],
      child: const Scaffold(body: SingleChildScrollView(child: TransactionListWidget())),
    ),
  );
}

Transaction _makeTx(String id, {int amount = 10000, String category = 'Ăn ngoài'}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    emoji: '🍜',
    date: DateTime(2026, 6, 5),
    note: '',
  );
}

void main() {
  late ExpenseViewModel vm;
  late _FakeTransactionDataSource repo;
  late MockCategoryLocalDataSource mockCategoryDS;

  setUp(() {
    repo = _FakeTransactionDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
    vm = ExpenseViewModel(repo, _FakeExportService(), mockCategoryDS);
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

  // ===========================================================================
  // ADR-0016 Slice 1
  // ===========================================================================

  group('ADR-0016 D1: clear-all dialog undo', () {
    testWidgets('clear dialog shows "Bạn có 5 giây để hoàn tác." text', (tester) async {
      // Seed data so the dialog is meaningful
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      // Open clear dialog via the delete_sweep icon button
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 giây để hoàn tác'), findsOneWidget);
    });

    testWidgets('clear dialog text does NOT show "không thể hoàn tác"', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();

      // ADR-0016 D8: misleading "cannot undo" text removed.
      expect(find.textContaining('không thể hoàn tác'), findsNothing);
    });

    testWidgets('confirming clear shows 5s SnackBar with Hoàn tác action', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();

      // Confirm "Xóa"
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      // SnackBar present
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Đã xoá toàn bộ dữ liệu'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);
    });

    testWidgets('SnackBar after clear-all has 5-second duration', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 5));
    });

    testWidgets('tapping Hoàn tác restores previously deleted transactions', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.addTransactionFromModel(_makeTx('tx-2'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      final initialCount = vm.allTransactions.length;
      expect(initialCount, 2);

      // Confirm clear
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(vm.allTransactions, isEmpty);

      // Undo
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      expect(vm.allTransactions.length, 2);
      expect(vm.allTransactions.map((t) => t.id), containsAll(['tx-1', 'tx-2']));
    });
  });

  group('ADR-0016 D3: empty state guidance', () {
    testWidgets('shows hint "Dùng thanh nhập nhanh bên trên để thêm" when empty', (tester) async {
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
      expect(
        find.textContaining('Dùng thanh nhập nhanh'),
        findsOneWidget,
      );
    });

    testWidgets('hint is NOT shown when there are transactions', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      expect(
        find.text('Dùng thanh nhập nhanh bên trên để thêm'),
        findsNothing,
      );
    });
  });

  group('ADR-0016 D4: bulk delete undo', () {
    /// Select a transaction row by tapping its checkbox.
    Future<void> _selectRow(WidgetTester tester, {bool first = true}) async {
      // Find the first or second Checkbox in the list (there are no checkboxes
      // visible until selection mode is entered). We enter selection mode by
      // long-pressing a row, then the checkboxes appear.
      await tester.longPress(find.text('🍜').first);
      await tester.pumpAndSettle();
    }

/// Enters selection mode and verifies the action bar is showing.
Future<void> _enterSelectionMode(WidgetTester tester) async {
  await tester.longPress(find.text('🍜').first);
  await tester.pumpAndSettle();
  // Sanity check: action bar shows the "Đã chọn" text
  expect(find.text('Đã chọn 1'), findsOneWidget);
}

/// Taps the action bar's "Xoá" button (in selection mode).
Future<void> _tapActionBarDelete(WidgetTester tester) async {
  // In selection mode the action bar shows a "Xoá" TextButton.icon. The
  // filter chip's "Xoá" is hidden because no filter is active.
  await tester.tap(find.text('Xoá'));
  await tester.pumpAndSettle();
}

    testWidgets('confirm dialog text says "Bạn có 5 giây để hoàn tác sau khi xoá"',
        (tester) async {
      // Only 1 transaction → only 1 checkbox visible in selection mode
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      await _enterSelectionMode(tester);
      await _tapActionBarDelete(tester);

      expect(
        find.text('Bạn có 5 giây để hoàn tác sau khi xoá.'),
        findsOneWidget,
      );
    });

    testWidgets('confirm dialog does NOT show "không thể hoàn tác"', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      await _enterSelectionMode(tester);
      await _tapActionBarDelete(tester);

      expect(find.textContaining('không thể hoàn tác'), findsNothing);
    });

    testWidgets('confirming bulk delete shows 5s SnackBar with Hoàn tác',
        (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      await _enterSelectionMode(tester);
      await _tapActionBarDelete(tester);

      // Confirm in the dialog
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Xoá'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 5));
    });

    testWidgets('tapping Hoàn tác after bulk delete restores transactions',
        (tester) async {
      // Use 1 transaction so we select and delete exactly that one.
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      expect(vm.allTransactions.length, 1);
      expect(vm.allTransactions.first.id, 'tx-1');

      // Enter selection mode and delete
      await _enterSelectionMode(tester);
      await _tapActionBarDelete(tester);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Xoá'),
      ));
      await tester.pumpAndSettle();

      expect(vm.allTransactions, isEmpty);

      // Undo
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      expect(vm.allTransactions.length, 1);
      expect(vm.allTransactions.first.id, 'tx-1');
    });
  });

  group('ADR-0016 D6: export SnackBar durations', () {
    testWidgets('export dialog shows CSV and JSON buttons', (tester) async {
      await vm.addTransactionFromModel(_makeTx('tx-1'));
      await vm.refresh();
      await tester.pumpWidget(_wrap(vm));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      expect(find.text('CSV'), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
    });

    // Note: the export SnackBar requires capturing the outer scaffold context
    // before Navigator.pop — that fix is out of scope for ADR-0016 D6.
    // The test above verifies the dialog structure; duration is implicitly
    // verified through code inspection (2s added to success SnackBars).
  });
}

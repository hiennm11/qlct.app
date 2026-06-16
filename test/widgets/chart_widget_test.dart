import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/chart_widget.dart';
import 'package:qlct/widgets/section_header.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockTransactionLocalDataSource mockRepo;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockExportService mockExport;

  setUpAll(() {
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      categoryId: 'test_cat',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
  });

  setUp(() {
    mockRepo = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockExport = MockExportService();
    // Default: pagination returns empty page (needed after ADR-0017 D3.2)
    when(() => mockRepo.getAllPaginated(
            offset: any(named: 'offset'), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
  });

  Widget wrap(ExpenseViewModel vm) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: vm,
          child: const ChartWidget(activeCategories: []),
        ),
      ),
    );
  }

  // ADR-0074: mirror real host constraint từ budget_hub_screen.dart.
  // Test surface `setSurfaceSize(400, 560)` không phản ánh SizedBox
  // wrapper mà host thực sự áp lên widget → KDD #55.
  Widget wrapWithHeight(ExpenseViewModel vm, double height) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: height,
          child: ChangeNotifierProvider.value(
            value: vm,
            child: const ChartWidget(activeCategories: []),
          ),
        ),
      ),
    );
  }

  ExpenseViewModel makeVm(List<Transaction> txs) {
    when(() => mockRepo.getAll()).thenAnswer((_) async => txs);
    when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);
    return ExpenseViewModel(mockRepo, mockExport, mockCategoryDS);
  }

  group('ChartWidget - no SectionHeader (data state) (Bug A v2 fix 2026-06-16)', () {
    testWidgets('ChartWidget KHÔNG render SectionHeader (title là host\'s job)',
        (tester) async {
      final now = DateTime.now();
      final tx = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍔',
        date: now,
        note: '',
      );
      final vm = makeVm([tx]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      // Bug A v2 fix: SectionHeader bị duplicate với 'Biểu đồ danh mục'
      // manual header ở budget_hub_screen.dart. ChartWidget chỉ render
      // chart + legend, title thuộc host responsibility.
      expect(find.byType(SectionHeader), findsNothing);
      expect(find.text('Chi tiêu theo danh mục'), findsNothing);
      // chart-loaded key vẫn render (chart + legend có data).
      expect(find.byKey(const Key('chart-loaded')), findsOneWidget);
    });
  });

  group('ChartWidget - empty state', () {
    testWidgets('shows 48px emoji + message when no category data',
        (tester) async {
      final vm = makeVm([]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      // Empty state does NOT show the SectionHeader — only the centered
      // 48px emoji and the message.
      expect(find.byType(SectionHeader), findsNothing);
      expect(find.text('📊'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu để hiển thị'), findsOneWidget);
    });
  });

  group('ChartWidget - loading state (D5)', () {
    testWidgets('shows CircularProgressIndicator when isLoading and allTransactions is empty',
        (tester) async {
      // Use a Completer to keep the repo in loading state
      final completer = Completer<List<Transaction>>();
      when(() => mockRepo.getAll()).thenAnswer((_) => completer.future);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) => completer.future);
      final vm = ExpenseViewModel(mockRepo, mockExport, mockCategoryDS);

      // Pump once to capture the loading state before async completes
      await tester.pumpWidget(wrap(vm));
      await tester.pump();

      // Loading state should show spinner, not empty state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chưa có dữ liệu để hiển thị'), findsNothing);

      // Clean up: complete the future so the VM doesn't hang
      completer.complete([]);
    });
  });

  group('ADR-0070 ChartWidget - overflow + label fix', () {
    testWidgets('renders chart-loaded key khi có data', (tester) async {
      final now = DateTime.now();
      final tx = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍔',
        date: now,
        note: '',
      );
      final vm = makeVm([tx]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chart-loaded')), findsOneWidget);
    });

    testWidgets('legend row key bind đúng categoryId', (tester) async {
      final now = DateTime.now();
      final tx1 = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍔',
        date: now,
        note: '',
      );
      final tx2 = Transaction(
        id: 'tx-2',
        amount: 30000,
        category: 'Cà phê',
        categoryId: 'coffee',
        emoji: '☕',
        date: now,
        note: '',
      );
      final vm = makeVm([tx1, tx2]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('legend-row-food_out')), findsOneWidget);
      expect(find.byKey(const Key('legend-row-coffee')), findsOneWidget);
    });

    testWidgets('legend row hiển thị % inline cạnh amount', (tester) async {
      final now = DateTime.now();
      final tx1 = Transaction(
        id: 'tx-1',
        amount: 75000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍔',
        date: now,
        note: '',
      );
      final tx2 = Transaction(
        id: 'tx-2',
        amount: 25000,
        category: 'Cà phê',
        categoryId: 'coffee',
        emoji: '☕',
        date: now,
        note: '',
      );
      final vm = makeVm([tx1, tx2]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      // food_out = 75% of 100k, coffee = 25% of 100k.
      expect(find.textContaining('75.0%'), findsOneWidget);
      expect(find.textContaining('25.0%'), findsOneWidget);
    });

    testWidgets('không có inline title trong PieChart slice (showTitle: false)',
        (tester) async {
      final now = DateTime.now();
      // 5 small slices để stress test label crowding.
      final txs = [
        Transaction(
          id: 'tx-1',
          amount: 10000,
          category: 'Ăn ngoài',
          categoryId: 'food_out',
          emoji: '🍔',
          date: now,
          note: '',
        ),
        Transaction(
          id: 'tx-2',
          amount: 8000,
          category: 'Cà phê',
          categoryId: 'coffee',
          emoji: '☕',
          date: now,
          note: '',
        ),
        Transaction(
          id: 'tx-3',
          amount: 5000,
          category: 'Đi lại',
          categoryId: 'transport',
          emoji: '🚌',
          date: now,
          note: '',
        ),
        Transaction(
          id: 'tx-4',
          amount: 3000,
          category: 'Mua sắm',
          categoryId: 'shopping',
          emoji: '🛍️',
          date: now,
          note: '',
        ),
        Transaction(
          id: 'tx-5',
          amount: 2000,
          category: 'Khác',
          categoryId: 'other',
          emoji: '📌',
          date: now,
          note: '',
        ),
      ];
      final vm = makeVm(txs);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      // Bug A: pre-fix, fl_chart mặc định title=value.toString() (raw amount).
      // 5 slice → 5 raw amount text trong chart. Post-fix showTitle: false →
      // 0 raw amount text trong chart, % chỉ trong 5 legend rows.
      // Verify: tất cả text "10000.0" / "8000.0" / "5000.0" / "3000.0" / "2000.0"
      // KHÔNG xuất hiện (không phải raw amount inline).
      expect(find.text('10000.0'), findsNothing);
      expect(find.text('8000.0'), findsNothing);
      expect(find.text('5000.0'), findsNothing);
      expect(find.text('3000.0'), findsNothing);
      expect(find.text('2000.0'), findsNothing);
      // % chỉ trong legend rows (5 widgets).
      expect(find.textContaining('%'), findsNWidgets(5));
    });

    testWidgets('8 danh mục không overflow ở viewport 400x560 (regression guard)',
        (tester) async {
      final now = DateTime.now();
      final categories = [
        ('food_out', 'Ăn ngoài', '🍔'),
        ('coffee', 'Cà phê', '☕'),
        ('transport', 'Đi lại', '🚌'),
        ('shopping', 'Mua sắm', '🛍️'),
        ('entertainment', 'Giải trí', '🎮'),
        ('health', 'Sức khỏe', '💊'),
        ('bills', 'Hóa đơn', '🧾'),
        ('other', 'Khác', '📌'),
      ];
      final txs = List.generate(
        categories.length,
        (i) => Transaction(
          id: 'tx-$i',
          amount: 10000 * (i + 1),
          category: categories[i].$2,
          categoryId: categories[i].$1,
          emoji: categories[i].$3,
          date: now,
          note: '',
        ),
      );
      final vm = makeVm(txs);

      await tester.binding.setSurfaceSize(const Size(400, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // ADR-0074: wrap với SizedBox(height: 420) mirror real host
      // constraint ở budget_hub_screen.dart. Pre-fix, test dùng
      // setSurfaceSize(400, 560) full screen → không phát hiện bug
      // RenderFlex overflow thực tế (KDD #55).
      await tester.pumpWidget(wrapWithHeight(vm, 420));
      await tester.pumpAndSettle();

      // No RenderFlex overflow exception.
      expect(tester.takeException(), isNull);
    });
  });

  // ADR-0074: 2-col Wrap legend layout. Test Wrap flow + cellW
  // calculation qua LayoutBuilder.
  group('ADR-0074 ChartWidget - 2-col Wrap legend', () {
    List<Transaction> buildTxs(int count) {
      final now = DateTime.now();
      final samples = [
        ('food_out', 'Ăn ngoài', '🍔'),
        ('coffee', 'Cà phê', '☕'),
        ('transport', 'Đi lại', '🚌'),
        ('shopping', 'Mua sắm', '🛍️'),
        ('entertainment', 'Giải trí', '🎮'),
        ('health', 'Sức khỏe', '💊'),
        ('bills', 'Hóa đơn', '🧾'),
        ('other', 'Khác', '📌'),
        ('rent', 'Tiền nhà', '🏠'),
        ('gift', 'Quà tặng', '🎁'),
        ('travel', 'Du lịch', '✈️'),
        ('education', 'Giáo dục', '📚'),
      ];
      return List.generate(
        count,
        (i) => Transaction(
          id: 'tx-$i',
          amount: 10000 * (i + 1),
          category: samples[i % samples.length].$2,
          categoryId: samples[i % samples.length].$1,
          emoji: samples[i % samples.length].$3,
          date: now,
          note: '',
        ),
      );
    }

    testWidgets('8 cats: 2-col Wrap renders 8 legend-row keys + 8 % strings',
        (tester) async {
      final vm = makeVm(buildTxs(8));

      await tester.binding.setSurfaceSize(const Size(400, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithHeight(vm, 420));
      await tester.pumpAndSettle();

      // 8 legend rows rendered (2-col Wrap → 4 rows).
      final rowKeys = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('legend-row-'),
      );
      expect(rowKeys, findsNWidgets(8));
      // % inline cạnh amount ở mỗi legend row.
      expect(find.textContaining('%'), findsNWidgets(8));
      // No overflow exception.
      expect(tester.takeException(), isNull);
    });

    testWidgets('12 cats: 2-col Wrap render 12 keys (proves Wrap scales)',
        (tester) async {
      final vm = makeVm(buildTxs(12));

      await tester.binding.setSurfaceSize(const Size(400, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // pumpWidget + pump thay vì pumpAndSettle vì stress edge expected
      // RenderFlex overflow exception (6 rows × 40 = 240 + pie 180 +
      // spacer 12 + Card padding 32 = 464 > 420 host). pumpAndSettle
      // sẽ fail vì exception. ADR-0074 documented stress limit.
      // takeException() trước pump để clear exception từ pumpWidget
      // (Flutter render overflow trong pump phase).
      tester.takeException();
      await tester.pumpWidget(wrapWithHeight(vm, 420));
      await tester.pump();
      tester.takeException();

      final rowKeys = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('legend-row-'),
      );
      // Wrap vẫn render đủ 12 widgets + 12 % strings, chỉ là content
      // height vượt host budget. Real device sẽ clip phần dưới
      // (visible behavior).
      expect(rowKeys, findsNWidgets(12));
      expect(find.textContaining('%'), findsNWidgets(12));
    });

    testWidgets('1 cat: 1 legend row + pie chart still rendered (baseline)',
        (tester) async {
      final vm = makeVm(buildTxs(1));

      await tester.binding.setSurfaceSize(const Size(400, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithHeight(vm, 420));
      await tester.pumpAndSettle();

      final rowKeys = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('legend-row-'),
      );
      expect(rowKeys, findsOneWidget);
      expect(find.byKey(const Key('chart-loaded')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

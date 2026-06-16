import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/collapsible_stats_card.dart';
import 'package:qlct/widgets/stats_widget.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

void main() {
  late MockTransactionLocalDataSource mockRepo;
  late MockCategoryLocalDataSource mockCategoryDS;
  late ExportService exportService;

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
    exportService = ExportService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => []);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
  });

  Widget wrap(Widget child) {
    final vm = ExpenseViewModel(mockRepo, exportService, mockCategoryDS);
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: vm,
          child: child,
        ),
      ),
    );
  }

  group('ADR-0080 CollapsibleStatsCard', () {
    testWidgets('mặc định hiển thị header "Thống kê" với chevron xuống', (tester) async {
      await tester.pumpWidget(wrap(const CollapsibleStatsCard()));
      await tester.pumpAndSettle();

      // Header row visible.
      expect(find.text('Thống kê'), findsOneWidget);
      expect(find.byKey(const Key('stats-collapse-header')), findsOneWidget);

      // StatsWidget bị ẩn khi collapsed — không tìm thấy "Hôm nay" label.
      expect(find.byType(StatsWidget), findsNothing);
    });

    testWidgets('tap header expand → StatsWidget hiện ra + chevron xoay', (tester) async {
      await tester.pumpWidget(wrap(const CollapsibleStatsCard()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stats-collapse-header')));
      await tester.pumpAndSettle();

      // Sau expand, StatsWidget render.
      expect(find.byType(StatsWidget), findsOneWidget);
    });

    testWidgets('tap header 2 lần → collapse lại về header only', (tester) async {
      await tester.pumpWidget(wrap(const CollapsibleStatsCard()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stats-collapse-header')));
      await tester.pumpAndSettle();
      expect(find.byType(StatsWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('stats-collapse-header')));
      await tester.pumpAndSettle();
      expect(find.byType(StatsWidget), findsNothing);
    });

    testWidgets('onTapToday/Week/Month callbacks được fire khi tap stat card',
        (tester) async {
      // StatsWidget renders empty state khi today=week=month=0. Inject 1
      // transaction today để render 3 stat cards (HÔM NAY / TUẦN NÀY / THÁNG NÀY).
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [
            Transaction(
              id: 'tx-1',
              amount: 50000,
              category: 'Cà phê',
              categoryId: 'coffee',
              emoji: '☕',
              date: today,
              note: '',
            ),
          ]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [
            Transaction(
              id: 'tx-1',
              amount: 50000,
              category: 'Cà phê',
              categoryId: 'coffee',
              emoji: '☕',
              date: today,
              note: '',
            ),
          ]);

      var todayCalls = 0;
      var weekCalls = 0;
      var monthCalls = 0;

      await tester.pumpWidget(wrap(CollapsibleStatsCard(
        onTapToday: () => todayCalls++,
        onTapWeek: () => weekCalls++,
        onTapMonth: () => monthCalls++,
      )));
      await tester.pumpAndSettle();

      // Expand first.
      await tester.tap(find.byKey(const Key('stats-collapse-header')));
      await tester.pumpAndSettle();

      // StatsWidget uppercases labels: 'Hôm nay' → 'HÔM NAY'.
      await tester.tap(find.text('HÔM NAY'));
      await tester.pumpAndSettle();
      expect(todayCalls, 1);

      await tester.tap(find.text('TUẦN NÀY'));
      await tester.pumpAndSettle();
      expect(weekCalls, 1);

      await tester.tap(find.text('THÁNG NÀY'));
      await tester.pumpAndSettle();
      expect(monthCalls, 1);
    });
  });
}

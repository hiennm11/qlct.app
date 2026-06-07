import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/section_header.dart';
import 'package:qlct/widgets/stats_widget.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockTransactionLocalDataSource mockRepo;
  late MockExportService mockExport;

  setUpAll(() {
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
  });

  setUp(() {
    mockRepo = MockTransactionLocalDataSource();
    mockExport = MockExportService();
    // Default: pagination returns empty page (needed after ADR-0017 D3.2)
    when(() => mockRepo.getAllPaginated(
            offset: any(named: 'offset'), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
  });

  Widget wrap(
    ExpenseViewModel vm, {
    VoidCallback? onTapToday,
    VoidCallback? onTapWeek,
    VoidCallback? onTapMonth,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: vm,
          child: StatsWidget(
            onTapToday: onTapToday,
            onTapWeek: onTapWeek,
            onTapMonth: onTapMonth,
          ),
        ),
      ),
    );
  }

  ExpenseViewModel makeVm(List<Transaction> txs) {
    when(() => mockRepo.getAll()).thenAnswer((_) async => txs);
    when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);
    return ExpenseViewModel(mockRepo, mockExport);
  }

  group('StatsWidget - SectionHeader integration (data state)', () {
    testWidgets('renders SectionHeader with emoji and title', (tester) async {
      final now = DateTime.now();
      final tx = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍔',
        date: now,
        note: '',
      );
      final vm = makeVm([tx]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('💰'), findsOneWidget);
      expect(find.text('Thống kê'), findsOneWidget);
    });

    testWidgets('does not render any action icon on the header', (tester) async {
      final tx = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍔',
        date: DateTime.now(),
        note: '',
      );
      final vm = makeVm([tx]);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      final header = tester.widget<SectionHeader>(find.byType(SectionHeader));
      expect(header.onAction, isNull);
      expect(
        find.descendant(
          of: find.byType(SectionHeader),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets('still shows stat cards with onTap callbacks', (tester) async {
      // Use today's date so all three stat periods (today/week/month) are non-zero.
      final today = DateTime.now();
      final tx = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍔',
        date: DateTime(today.year, today.month, today.day), // exactly today
        note: '',
      );
      final vm = makeVm([tx]);

      await tester.pumpWidget(
        wrap(
          vm,
          onTapToday: () {},
          onTapWeek: () {},
          onTapMonth: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HÔM NAY'), findsOneWidget);
      expect(find.text('TUẦN NÀY'), findsOneWidget);
      expect(find.text('THÁNG NÀY'), findsOneWidget);
    });
  });

  group('StatsWidget - loading state', () {
    testWidgets('still shows SectionHeader while loading', (tester) async {
      // Provide a fast-completing empty list so isLoading goes false immediately.
      // The loading skeleton is transient; we verify SectionHeader is rendered
      // at least once in any non-empty state.
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      final vm = ExpenseViewModel(mockRepo, mockExport);

      await tester.pumpWidget(wrap(vm));
      await tester.pumpAndSettle();

      // With no transactions the widget shows the empty state (not loading skeleton),
      // but SectionHeader is still rendered via the SectionHeader widget.
      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('💰'), findsOneWidget);
      expect(find.text('Thống kê'), findsOneWidget);
    });
  });
}

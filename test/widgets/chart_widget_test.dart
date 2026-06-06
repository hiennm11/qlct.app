import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/chart_widget.dart';
import 'package:qlct/widgets/section_header.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockTransactionRepository mockRepo;
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
    mockRepo = MockTransactionRepository();
    mockExport = MockExportService();
  });

  Widget wrap(ExpenseViewModel vm) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: vm,
          child: const ChartWidget(),
        ),
      ),
    );
  }

  ExpenseViewModel makeVm(List<Transaction> txs) {
    when(() => mockRepo.getAll()).thenAnswer((_) async => txs);
    return ExpenseViewModel(mockRepo, mockExport);
  }

  group('ChartWidget - SectionHeader integration (data state)', () {
    testWidgets('renders SectionHeader with emoji and title when data exists',
        (tester) async {
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
      expect(find.text('📊'), findsOneWidget);
      expect(find.text('Chi tiêu theo danh mục'), findsOneWidget);
    });

    testWidgets('has no action button on the header', (tester) async {
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
}

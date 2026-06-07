import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/widgets/chart_widget.dart';
import 'package:qlct/widgets/section_header.dart';

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
    when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
        .thenAnswer((_) async => txs);
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

  group('ChartWidget - loading state (D5)', () {
    testWidgets('shows CircularProgressIndicator when isLoading and allTransactions is empty',
        (tester) async {
      // Use a Completer to keep the repo in loading state
      final completer = Completer<List<Transaction>>();
      when(() => mockRepo.getAll()).thenAnswer((_) => completer.future);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) => completer.future);
      final vm = ExpenseViewModel(mockRepo, mockExport);

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
}

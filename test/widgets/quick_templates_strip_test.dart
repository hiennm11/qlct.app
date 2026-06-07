import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/data/datasources/quick_template_local_datasource.dart';
import 'package:qlct/viewmodels/quick_template_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/widgets/quick_templates_strip.dart';

class MockQuickTemplateDataSource extends Mock
    implements QuickTemplateLocalDataSource {}

class MockTransactionDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockQuickTemplateDataSource mockDs;
  late MockTransactionDataSource mockTxDs;
  late MockExportService mockExport;
  late QuickTemplateViewModel vm;
  late ExpenseViewModel expenseVM;

  final sampleTemplate = QuickTemplate(
    id: 't-1',
    title: 'Cơm trưa',
    amount: 35000,
    categoryName: 'Ăn ngoài',
    emoji: '🍜',
    isPinned: true,
    usageCount: 5,
    createdAt: DateTime(2026, 6, 7),
    updatedAt: DateTime(2026, 6, 7),
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 6, 7));
    registerFallbackValue(sampleTemplate);
    registerFallbackValue(FakeTransaction());
  });

  setUp(() {
    mockDs = MockQuickTemplateDataSource();
    mockTxDs = MockTransactionDataSource();
    mockExport = MockExportService();

    when(() => mockDs.getAll()).thenAnswer((_) async => []);
    when(() => mockTxDs.getAllPaginated(offset: any(named: 'offset'), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);

    vm = QuickTemplateViewModel(mockDs);
    expenseVM = ExpenseViewModel(mockTxDs, mockExport);
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm),
            ChangeNotifierProvider.value(value: expenseVM),
          ],
          child: const QuickTemplatesStrip(),
        ),
      ),
    );
  }

  testWidgets('empty state shows "Tạo mẫu nhanh" chip', (tester) async {
    await tester.pumpWidget(buildWidget());
    // pump to allow the Future.microtask to complete
    await tester.pump();
    await tester.pump(); // ensure notifyListeners propagates
    await tester.pumpAndSettle();

    expect(find.text('Tạo mẫu nhanh'), findsOneWidget);
  });

  testWidgets('shows template chips when templates exist', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Cơm trưa'), findsOneWidget);
    // "Tạo mẫu nhanh" entry still shows when templates exist
    expect(find.text('Tạo mẫu nhanh'), findsOneWidget);
  });

  testWidgets('tapping template chip calls addTransaction and markUsed', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pumpAndSettle();

    verify(() => mockTxDs.add(any())).called(1);
    verify(() => mockDs.markUsed('t-1', any())).called(1);
  });

  testWidgets('snackbar shown after tapping template', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pump();

    expect(find.text('Đã thêm "Cơm trưa"'), findsOneWidget);
  });

  testWidgets('calls addTransaction then markUsed on success', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pump();

    final addCall = verify(() => mockTxDs.add(captureAny())).captured.single;
    expect(addCall.amount, 35000);
    expect(addCall.category, 'Ăn ngoài');
    expect(addCall.emoji, '🍜');

    verify(() => mockDs.markUsed('t-1', any())).called(1);
  });

  testWidgets('known category uses predefined emoji', (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenAnswer((_) async {});
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pump();

    final addCall = verify(() => mockTxDs.add(captureAny())).captured.single;
    expect(addCall.emoji, '🍜'); // predefined emoji from Category
  });

  // Issue #2: addTransaction sets errorMessage on failure (doesn't throw).
  // markUsed must NOT be called when add fails.
  testWidgets('add fails sets errorMessage — no markUsed, error snackbar',
      (tester) async {
    when(() => mockDs.getAll()).thenAnswer((_) async => [sampleTemplate]);
    when(() => mockTxDs.add(any())).thenThrow(Exception('db error'));
    when(() => mockDs.markUsed(any(), any())).thenAnswer((_) async {});

    await vm.forceReload();

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cơm trưa'));
    await tester.pumpAndSettle();

    // markUsed must NOT be called when add failed
    verifyNever(() => mockDs.markUsed(any(), any()));
    // Error snackbar must be shown
    expect(find.text('Không thể thêm "Cơm trưa"'), findsOneWidget);
  });

  // Issue #4: ManageTemplatesSheet._confirmDelete must NOT show success
  // snackbar when delete returns false. Covered by unit test
  // (quick_template_viewmodel_test.dart) + the logic mirror below.
  test('delete returns false sets errorMessage (no success)', () async {
    when(() => mockDs.delete('t-1')).thenThrow(Exception('db error'));
    final result = await vm.delete('t-1');
    expect(result, isFalse);
    expect(vm.errorMessage, isNotNull);
    // Caller must check result before showing success snackbar
  });
}

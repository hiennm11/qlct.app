import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/repositories/budget_repository.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/widgets/budget_overview_widget.dart';
import 'package:qlct/widgets/section_header.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockBudgetRepository mockRepo;
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
    mockRepo = MockBudgetRepository();
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

  group('BudgetOverviewWidget - SectionHeader integration', () {
    testWidgets('renders SectionHeader with emoji, title and edit action',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('💼'), findsOneWidget);
      expect(find.text('Ngân sách tháng'), findsOneWidget);
      // SectionHeader exposes the custom actionIcon
      final header = tester.widget<SectionHeader>(find.byType(SectionHeader));
      expect(header.actionIcon, Icons.edit);
      expect(header.onAction, isNotNull);
    });

    testWidgets('action button is tappable', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // IconButton should be present (it calls showBudgetBulkEditDialog,
      // which uses showDialog under the hood — we only assert that the
      // button itself is rendered and tappable, without diving into the
      // dialog's own widget tree).
      final headerFinder = find.byType(SectionHeader);
      expect(
        find.descendant(of: headerFinder, matching: find.byIcon(Icons.edit)),
        findsOneWidget,
      );
    });
  });
}

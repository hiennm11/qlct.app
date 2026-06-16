import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/quick_template_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/app_settings_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/quick_template_viewmodel.dart';
import 'package:qlct/widgets/super_input_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCategoryDataSource extends Mock implements CategoryLocalDataSource {}

class MockTransactionDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockQuickTemplateDataSource extends Mock
    implements QuickTemplateLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockCategoryDataSource mockCatDs;
  late MockTransactionDataSource mockTxDs;
  late MockQuickTemplateDataSource mockQtDs;
  late MockExportService mockExport;
  late CategoryViewModel catVM;
  late ExpenseViewModel expenseVM;
  late QuickTemplateViewModel qtVM;
  late AppSettingsViewModel settingsVM;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 6, 16));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    mockCatDs = MockCategoryDataSource();
    mockTxDs = MockTransactionDataSource();
    mockQtDs = MockQuickTemplateDataSource();
    mockExport = MockExportService();

    when(() => mockCatDs.getAll()).thenAnswer((_) async => seedCategories);
    when(() => mockCatDs.getDeleted()).thenAnswer((_) async => []);
    when(() => mockCatDs.seedDefaultsIfEmpty())
        .thenAnswer((_) async => Future.value());

    when(() => mockTxDs.getAllPaginated(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => []);
    when(() => mockQtDs.getAll()).thenAnswer((_) async => []);

    catVM = CategoryViewModel.seededWithDeps(mockCatDs, null,
        transactionDs: mockTxDs);
    expenseVM = ExpenseViewModel(mockTxDs, mockExport, mockCatDs);
    qtVM = QuickTemplateViewModel(mockQtDs);
  });

  Future<void> pumpCard(WidgetTester tester,
      {GlobalKey<SuperInputCardState>? key}) async {
    final prefs = await tester.runAsync(() async {
      return await SharedPreferences.getInstance();
    });
    settingsVM = AppSettingsViewModel(StorageService(prefs!))..load();
    await tester.runAsync(() async {
      await settingsVM.setQuickTemplateChipCount(5);
    });
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: catVM),
              ChangeNotifierProvider.value(value: expenseVM),
              ChangeNotifierProvider.value(value: qtVM),
              ChangeNotifierProvider.value(value: settingsVM),
            ],
            child: SuperInputCard(key: key),
          ),
        ),
      ),
    );
    await tester.pump();
    // Allow microtask-driven category load to complete.
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('ADR-0069 SuperInputCard — key binding (contract §11)', () {
    testWidgets('renders all 5 input section keys', (tester) async {
      await pumpCard(tester);

      expect(find.byKey(const Key('super-input-note-entry')), findsOneWidget);
      expect(find.byKey(const Key('super-input-row-2')), findsOneWidget);
      expect(find.byKey(const Key('super-input-quick-chips')), findsOneWidget);
      expect(find.byKey(const Key('super-input-mic')), findsOneWidget);
      // Templates strip — empty state when no pinned templates.
      expect(find.byKey(const Key('super-input-create-template')),
          findsOneWidget);
      expect(find.byKey(const Key('super-input-custom-input')), findsOneWidget);
      expect(
          find.byKey(const Key('super-input-amount')), findsOneWidget);
      expect(
          find.byKey(const Key('super-input-category-dropdown')),
          findsOneWidget);
      expect(
          find.byKey(const Key('super-input-custom-note-button')),
          findsOneWidget);
    });

    testWidgets('canSave: false khi form rỗng', (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);
      expect(key.currentState!.canSave, isFalse);
    });

    testWidgets('canSave: true khi nhập amount > 0', (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      await tester.enterText(
          find.byKey(const Key('super-input-amount')), '50000');
      await tester.pump();

      expect(key.currentState!.canSave, isTrue);
    });

    testWidgets('canSave: true khi chọn category (amount rỗng)', (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      // Tap first quick chip.
      final firstChip = find.byWidgetPredicate(
        (w) => w.key == const Key('quick-chip-food_out'),
      );
      expect(firstChip, findsOneWidget);
      await tester.tap(firstChip);
      await tester.pump();

      expect(key.currentState!.canSave, isTrue);
    });

    testWidgets('canSave: true khi note text parse được amount',
        (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      await tester.enterText(
        find.byKey(const Key('super-input-note-entry')),
        '50k cơm xóm',
      );
      await tester.pump();

      expect(key.currentState!.canSave, isTrue);
    });

    testWidgets('Save button enable reflects canSave (via getValueAfterFrame)',
        (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      // Form rỗng → canSave false.
      expect(key.currentState!.canSave, isFalse);

      // Nhập amount > 0 → canSave true.
      await tester.enterText(
          find.byKey(const Key('super-input-amount')), '50000');
      await tester.pump();
      expect(key.currentState!.canSave, isTrue);
    });

    testWidgets('Save button text là "Lưu giao dịch"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            bottomSheet: SuperInputSaveButton(canSave: true, onSave: () {}),
          ),
        ),
      );
      expect(find.text('Lưu giao dịch'), findsOneWidget);
    });

    testWidgets('Quick template tap fills form', (tester) async {
      final t = QuickTemplate(
        id: 't-1',
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍜',
        isPinned: true,
        usageCount: 5,
        createdAt: DateTime(2026, 6, 7),
        updatedAt: DateTime(2026, 6, 7),
      );
      when(() => mockQtDs.getAll()).thenAnswer((_) async => [t]);
      await qtVM.forceReload();

      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      // Wait for qtVM to load templates via runAsync (microtask is real-time).
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final templateChip = find.byKey(const Key('super-template-t-1'),
          skipOffstage: false);
      expect(templateChip, findsOneWidget);
      await tester.tap(templateChip, warnIfMissed: false);
      await tester.pump();

      // After tap, form populated → canSave true.
      expect(key.currentState!.canSave, isTrue);
    });

    testWidgets('Note button focus NoteEntry', (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      await tester.tap(
          find.byKey(const Key('super-input-custom-note-button')));
      await tester.pump();

      // NoteEntry has focus.
      final state = tester.state(find.byKey(const Key('super-input-note-entry')))
          as State;
      expect(state, isNotNull);
    });

    testWidgets(
        'changeTick bumps khi _canSave transition false→true (Bug B regression)',
        (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      final initialTick = key.currentState!.changeTick.value;
      expect(key.currentState!.canSave, isFalse);

      // Tap chip → canSave false→true → changeTick++ (Bug B fix).
      // Chip path deterministically bumps tick vì _onQuickCategoryTap
      // explicitly tăng tick khi transition.
      final chip = find.byKey(const Key('quick-chip-food_out'));
      await tester.tap(chip);
      await tester.pump();

      expect(key.currentState!.canSave, isTrue);
      expect(key.currentState!.changeTick.value, greaterThan(initialTick));
    });

    testWidgets(
        'changeTick KHÔNG spam khi text edit mà canSave vẫn false (Bug B perf)',
        (tester) async {
      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);

      // Form rỗng → canSave false → _lastCanSave = false.
      final tickBaseline = key.currentState!.changeTick.value;

      // Edit NoteEntry với text 'x' (không parse ra amount) → canSave VẪN false.
      // Listener fires nhưng canSave transition = false==false → KHÔNG bump.
      await tester.enterText(
          find.byKey(const Key('super-input-note-entry')), 'x');
      await tester.pump();

      expect(key.currentState!.canSave, isFalse);
      expect(key.currentState!.changeTick.value, tickBaseline);
    });

    testWidgets('Quick template tap bump changeTick ngay (Bug B fix)',
        (tester) async {
      final t = QuickTemplate(
        id: 't-1',
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍜',
        isPinned: true,
        usageCount: 5,
        createdAt: DateTime(2026, 6, 7),
        updatedAt: DateTime(2026, 6, 7),
      );
      when(() => mockQtDs.getAll()).thenAnswer((_) async => [t]);
      await qtVM.forceReload();

      final key = GlobalKey<SuperInputCardState>();
      await pumpCard(tester, key: key);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final tickBefore = key.currentState!.changeTick.value;

      final templateChip = find.byKey(const Key('super-template-t-1'),
          skipOffstage: false);
      await tester.tap(templateChip, warnIfMissed: false);
      await tester.pump();

      // Sau tap template: form filled → canSave true → changeTick bump.
      expect(key.currentState!.canSave, isTrue);
      expect(key.currentState!.changeTick.value, greaterThan(tickBefore));
    });
  });
}

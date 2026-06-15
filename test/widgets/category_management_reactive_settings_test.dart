import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/app_settings_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/views/category_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build 1 trash item with `deletedAt = now - 26 days` để
/// `itemsApproachingPurge` return non-empty (warning range 25-30 days).
Category _trashApproaching() {
  final now = DateTime.now();
  return Category(
    id: 'trash-cat',
    name: 'Danh mục cũ',
    normalizedName: 'danh muc cu',
    emoji: '📦',
    kind: CategoryKind.spending,
    budgetBehavior: BudgetBehavior.flexible,
    quickAmountMin: 0,
    quickAmountDefault: 0,
    quickAmountMax: 0,
    voicePhrases: const [],
    sortOrder: 100,
    isSystem: false,
    isArchived: false,
    // 26 days ago → trong warning range [25, 30) → approachingPurge returns it.
    deletedAt: now.subtract(const Duration(days: 26)),
    createdAt: now,
    updatedAt: now,
  );
}

/// Pump [CategoryManagementScreen] với [CategoryViewModel] chứa 1 trash
/// item approaching purge, plus [AppSettingsViewModel] cho reactive gate.
/// Capture AppSettingsViewModel handle để test có thể mutate nó từ ngoài
/// (proves Selector rebuild reactive, không cần Navigator dance).
Future<AppSettingsViewModel> _pumpScreen(WidgetTester tester) async {
  late final AppSettingsViewModel settingsVM;
  await tester.runAsync(() async {
    final prefs = await SharedPreferences.getInstance();
    settingsVM = AppSettingsViewModel(StorageService(prefs))..load();
  });
  // Use seeded() (sync) cho CategoryViewModel. deletedCategories computed
  // từ allCategories WHERE deleted_at IS NOT NULL.
  final vm = CategoryViewModel.seeded([_trashApproaching()]);
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<CategoryViewModel>.value(value: vm),
          ChangeNotifierProvider<AppSettingsViewModel>.value(value: settingsVM),
        ],
        child: const CategoryManagementScreen(),
      ),
    ),
  );
  await tester.pump();
  return settingsVM;
}

void main() {
  // ADR-0050: validate reactive assertion — toggle setting ở Settings rebuild
  // trash warning banner NGAY, không cần pop route. Đóng known limitation
  // từ ADR-0047 §Consequences.
  group('CategoryManagementScreen reactive settings (ADR-0050)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'reactive: toggle autoPurgeEnabled OFF → trash banner disappears without pop',
      (tester) async {
        final settingsVM = await _pumpScreen(tester);

        // State A: autoPurgeEnabled=true, trash has 1 item → banner visible.
        expect(settingsVM.autoPurgeEnabled, isTrue);
        expect(find.byKey(const Key('state-trash-purge-warning')), findsOneWidget);

        // Mutate VM (simulating user toggle ở SettingsScreen — same tree,
        // no Navigator push needed để prove reactivity).
        await tester.runAsync(() async {
          await settingsVM.setAutoPurgeEnabled(false);
        });
        await tester.pump();

        // State B: autoPurgeEnabled=false → banner GONE. No pop required.
        expect(settingsVM.autoPurgeEnabled, isFalse);
        expect(find.byKey(const Key('state-trash-purge-warning')), findsNothing);
      },
    );

    testWidgets(
      'reactive: toggle autoPurgeEnabled ON → trash banner reappears without pop',
      (tester) async {
        final settingsVM = await _pumpScreen(tester);

        // Set initial state = OFF, verify banner absent.
        await tester.runAsync(() async {
          await settingsVM.setAutoPurgeEnabled(false);
        });
        await tester.pump();
        expect(find.byKey(const Key('state-trash-purge-warning')), findsNothing);

        // Toggle back ON.
        await tester.runAsync(() async {
          await settingsVM.setAutoPurgeEnabled(true);
        });
        await tester.pump();

        // Banner reappears — proves symmetric reactivity.
        expect(find.byKey(const Key('state-trash-purge-warning')), findsOneWidget);
      },
    );

    testWidgets(
      'reactive: navigation path (pop) still works — regression guard',
      (tester) async {
        final settingsVM = await _pumpScreen(tester);

        // Simulate: settings still ON, push SettingsScreen, pop, banner present.
        expect(find.byKey(const Key('state-trash-purge-warning')), findsOneWidget);

        // Push a different screen on top via Navigator (simulating Settings
        // navigation). After pop, banner unchanged.
        final navState = tester.state<NavigatorState>(find.byType(Navigator));
        navState.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Settings placeholder'))),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Banner still visible (CategoryManagement route bên dưới stack).
        expect(find.byKey(const Key('state-trash-purge-warning')), findsOneWidget);

        // Pop.
        navState.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Banner still present (settingsVM unchanged, no pop-time side effect).
        expect(settingsVM.autoPurgeEnabled, isTrue);
        expect(find.byKey(const Key('state-trash-purge-warning')), findsOneWidget);
      },
    );
  });
}

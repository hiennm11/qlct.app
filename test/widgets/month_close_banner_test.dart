import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_plan.dart';
import 'package:qlct/models/category.dart' show seedCategories;
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/services/monthly_budget_plan_builder.dart';
import 'package:qlct/viewmodels/app_settings_viewmodel.dart';
import 'package:qlct/viewmodels/monthly_plan_viewmodel.dart';
import 'package:qlct/widgets/month_close_banner.dart';

class MockBudgetPlanLocalDataSource extends Mock implements BudgetPlanLocalDataSource {}
class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}
class MockBudgetSnapshotLocalDataSource extends Mock implements BudgetSnapshotLocalDataSource {}
class MockTransactionLocalDataSource extends Mock implements TransactionLocalDataSource {}
class MockCategoryLocalDataSource extends Mock implements CategoryLocalDataSource {}
class MockStorageService extends Mock implements StorageService {}

class FakeBudgetPlan extends Fake implements BudgetPlan {}
class FakeBudgetPlanItem extends Fake implements BudgetPlanItem {}

void main() {
  late MockBudgetPlanLocalDataSource mockPlanDS;
  late MockBudgetLocalDataSource mockBudgetDS;
  late MockBudgetSnapshotLocalDataSource mockSnapshotDS;
  late MockTransactionLocalDataSource mockTxDS;
  late MockCategoryLocalDataSource mockCategoryDS;
  late MockStorageService mockAppSettingsStorage;
  late MockStorageService mockStorage;
  late AppSettingsViewModel appSettings;
  late MonthlyPlanViewModel planVM;

  setUpAll(() async {
    registerFallbackValue(FakeBudgetPlan());
    registerFallbackValue(<BudgetPlanItem>[]);
    // DateFormat với locale 'vi_VN' cần locale data init.
    await initializeDateFormatting('vi_VN');
  });

  Future<void> setUpBanner({
    DateTime? now,
    BudgetPlan? plan,
  }) async {
    mockPlanDS = MockBudgetPlanLocalDataSource();
    mockBudgetDS = MockBudgetLocalDataSource();
    mockSnapshotDS = MockBudgetSnapshotLocalDataSource();
    mockTxDS = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    mockStorage = MockStorageService();
    mockAppSettingsStorage = MockStorageService();

    when(() => mockPlanDS.getDraft(any())).thenAnswer((_) async => plan);
    when(() => mockPlanDS.getItems(any())).thenAnswer((_) async => <BudgetPlanItem>[]);
    when(() => mockPlanDS.saveDraft(any(), any())).thenAnswer((_) async {});
    when(() => mockBudgetDS.getAll()).thenAnswer((_) async => <Budget>[]);
    when(() => mockSnapshotDS.getByYearMonth(any())).thenAnswer((_) async => []);
    when(() => mockTxDS.getByDateRange(any(), any())).thenAnswer((_) async => []);
    when(() => mockStorage.loadValue<int>('total_budget')).thenReturn(null);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => seedCategories);

    // AppSettingsViewModel: default dismissed = false
    when(() => mockAppSettingsStorage.loadValue<bool>(any())).thenReturn(null);
    when(() => mockAppSettingsStorage.saveValue(any(), any()))
        .thenAnswer((_) async {});

    planVM = MonthlyPlanViewModel(
      budgetPlanDataSource: mockPlanDS,
      budgetDataSource: mockBudgetDS,
      budgetSnapshotDataSource: mockSnapshotDS,
      transactionDataSource: mockTxDS,
      categoryDataSource: mockCategoryDS,
      storageService: mockStorage,
      builder: MonthlyBudgetPlanBuilder(),
      now: now ?? DateTime(2026, 6, 25),
    );
    await planVM.load();

    appSettings = AppSettingsViewModel(mockAppSettingsStorage);
  }

  Widget buildBanner({DateTime? now}) {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppSettingsViewModel>.value(value: appSettings),
            ChangeNotifierProvider<MonthlyPlanViewModel>.value(value: planVM),
          ],
          child: MonthCloseBanner(now: now),
        ),
      ),
    );
  }

  testWidgets('renders nothing when dayOfMonth < 25 (entry rule)', (tester) async {
    // Use fixedNow = 2026-06-10 (day=10, before 25)
    final now = DateTime(2026, 6, 10);
    await setUpBanner(now: now);
    await tester.pumpWidget(buildBanner(now: now));
    await tester.pumpAndSettle();

    // mc-state-dismissed key is used for both "dismissed" and "before day 25"
    // branches (sized box returned). Verify banner Card not visible.
    expect(find.byKey(const Key('mc-state-visible')), findsNothing);
  });

  testWidgets('renders draft copy + 2 CTAs on day 25 with auto-created draft', (tester) async {
    // Use fixedNow = 2026-06-25 (day=25, entry rule met). VM tự tạo draft
    // nếu chưa có → state hiển thị là "draft" (không phải no-plan).
    final now = DateTime(2026, 6, 25);
    await setUpBanner(now: now);
    await tester.pumpWidget(buildBanner(now: now));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mc-state-visible')), findsOneWidget);
    expect(find.byKey(const Key('mc-cta-plan')), findsOneWidget);
    expect(find.byKey(const Key('mc-cta-review')), findsOneWidget);
    expect(find.text('Mở kế hoạch'), findsOneWidget);
    expect(find.text('Xem tổng kết'), findsOneWidget);
  });

  testWidgets('renders applied copy when plan has appliedAt', (tester) async {
    final now = DateTime(2026, 6, 26);
    final appliedPlan = BudgetPlan(
      yearMonth: '202607',
      plannedTotalBudget: 5000000,
      source: 'previousMonth',
      status: 'applied',
      createdAt: now,
      updatedAt: now,
      appliedAt: now,
    );
    await setUpBanner(now: now, plan: appliedPlan);
    await tester.pumpWidget(buildBanner(now: now));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mc-state-visible')), findsOneWidget);
    expect(find.text('Xem kế hoạch'), findsOneWidget);
  });

  testWidgets('dismiss icon hides banner + shows Undo snackbar', (tester) async {
    final now = DateTime(2026, 6, 27);
    await setUpBanner(now: now);
    await tester.pumpWidget(buildBanner(now: now));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mc-state-visible')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mc-dismiss')));
    await tester.pump(); // notifyListeners
    await tester.pumpAndSettle();

    // Banner is now dismissed → SizedBox.shrink returned
    expect(find.byKey(const Key('mc-state-visible')), findsNothing);
    // Undo snackbar visible
    expect(find.byKey(const Key('mc-undo')), findsOneWidget);
    expect(find.text('Đã ẩn gợi ý chốt tháng'), findsOneWidget);
  });

  testWidgets('previousMonthKey formats correctly across year boundary', (tester) async {
    // January 2026 → previous = December 2025 → '202512'
    final jan = DateTime(2026, 1, 5);
    expect(MonthCloseBanner.previousMonthKey(jan), '202512');
    // June 2026 → previous = May 2026 → '202605'
    final jun = DateTime(2026, 6, 5);
    expect(MonthCloseBanner.previousMonthKey(jun), '202605');
  });
}

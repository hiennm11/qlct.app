import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/database/database_helper.dart';
import 'data/datasources/sqlite_transaction_datasource.dart';
import 'data/datasources/sqlite_budget_datasource.dart';
import 'data/datasources/sqlite_budget_snapshot_datasource.dart';
import 'data/datasources/sqlite_budget_plan_datasource.dart';
import 'data/datasources/sqlite_recurring_datasource.dart';
import 'data/datasources/sqlite_category_datasource.dart';
import 'data/datasources/sqlite_quick_template_datasource.dart';
import 'data/datasources/transaction_local_datasource.dart';
import 'data/datasources/budget_local_datasource.dart';
import 'data/datasources/budget_snapshot_local_datasource.dart';
import 'data/datasources/budget_plan_local_datasource.dart';
import 'data/datasources/recurring_local_datasource.dart';
import 'data/datasources/quick_template_local_datasource.dart';
import 'data/datasources/category_local_datasource.dart';
import 'data/migrations/shared_prefs_to_sqlite.dart';
import 'services/storage_service.dart';
import 'services/export_service.dart';
import 'services/backup_service.dart';
import 'services/monthly_budget_plan_builder.dart';
import 'viewmodels/expense_viewmodel.dart';
import 'viewmodels/budget_viewmodel.dart';
import 'viewmodels/recurring_viewmodel.dart';
import 'viewmodels/quick_template_viewmodel.dart';
import 'viewmodels/backup_viewmodel.dart';
import 'viewmodels/monthly_review_viewmodel.dart';
import 'viewmodels/monthly_plan_viewmodel.dart';
import 'viewmodels/category_viewmodel.dart';
import 'viewmodels/app_settings_viewmodel.dart';
import 'viewmodels/weekly_review_viewmodel.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ADR-0010 + sentry-init-guard: skip SentryFlutter.init entirely khi DSN
  // rỗng HOẶC malformed. Sentry SDK tự parse DSN → Uri trong
  // SentryOptions.parsedDsn getter, chạy TRƯỚC options callback.
  //
  // 2 lớp guard:
  // 1. Empty string check (compile-time const rỗng).
  // 2. Uri.tryParse validation — chống case DSN = ':SENTRY_DSN' (bash expansion
  //    của `$env:SENTRY_DSN` không thấy PowerShell env var, sinh ra string
  //    ':SENTRY_DSN' với empty scheme). Uri.tryParse bắt được và skip init.
  const sentryDsnRaw = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  final sentryDsn = _normalizeDsn(sentryDsnRaw);
  if (sentryDsn == null) {
    debugPrint('⚠️ SENTRY_DSN not set or malformed — crash reporting disabled');
    await _initApp();
    return;
  }

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
        options.attachScreenshot = false;
        options.sendDefaultPii = false;
        options.diagnosticLevel = SentryLevel.warning;
      },
      appRunner: () {
        _initApp();
      },
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Error during initialization: $e');
    debugPrint('📍 Stack trace: $stackTrace');
    runApp(_buildErrorApp());
  }
}

/// Returns a valid Sentry DSN string or null if input is empty/malformed.
/// DSN format: `https://<key>@<host>/<project>` — must parse as Uri with
/// non-empty scheme + host. Catches: empty string, `:SENTRY_DSN` (bash
/// expansion of `$env:SENTRY_DSN` literal), and other malformed inputs.
String? _normalizeDsn(String raw) {
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme.isEmpty) return null;
  if (uri.host.isEmpty) return null;
  return raw;
}

Future<void> _initApp() async {
  // ADR-0055: cold start perf — timestamp checkpoints for Phase A/B/C profiling.
  final t0 = DateTime.now().millisecondsSinceEpoch;
  debugPrint('⏱ [t+0] _initApp start');

  // Initialize dependencies
  debugPrint('⏱ [Phase A] SharedPreferences + DB init (parallel, ADR-0055 §Fix 1)');
  final results = await Future.wait<dynamic>([
    SharedPreferences.getInstance(),
    Future(() async {
      final helper = DatabaseHelper();
      await helper.database; // force init
      return helper;
    }),
  ]);
  final prefs = results[0] as SharedPreferences;
  final dbHelper = results[1] as DatabaseHelper;
  debugPrint('⏱ [t+${DateTime.now().millisecondsSinceEpoch - t0}ms] SharedPreferences + DB ready');

  // Initialize StorageService for SharedPreferences
  final storageService = StorageService(prefs);

  final transactionDataSource = SqliteTransactionDataSource(dbHelper);

  debugPrint('⏱ [Phase A] MigrationService.migrate()');
  final migrationService = MigrationService(dbHelper);
  await migrationService.migrate();
  debugPrint('⏱ [t+${DateTime.now().millisecondsSinceEpoch - t0}ms] Migration done');

  final exportService = ExportService();

  final categoryDataSource = SqliteCategoryDataSource(dbHelper);
  final budgetDataSource = SqliteBudgetDataSource(dbHelper);
  final budgetSnapshotDataSource = SqliteBudgetSnapshotDataSource(dbHelper);
  final budgetPlanDataSource = SqliteBudgetPlanDataSource(dbHelper);
  final recurringDataSource = SqliteRecurringDataSource(dbHelper);
  final quickTemplateDataSource = SqliteQuickTemplateDataSource(dbHelper);

  final backupService = BackupService(
    transactionDataSource,
    budgetDataSource,
    budgetSnapshotDataSource,
    budgetPlanDataSource,
    recurringDataSource,
    quickTemplateDataSource,
    categoryDataSource,
    storageService,
    dbHelper,
  );

  debugPrint('⏱ [t+${DateTime.now().millisecondsSinceEpoch - t0}ms] runApp()');
  runApp(MyApp(
    transactionDataSource: transactionDataSource,
    budgetDataSource: budgetDataSource,
    budgetSnapshotDataSource: budgetSnapshotDataSource,
    budgetPlanDataSource: budgetPlanDataSource,
    recurringDataSource: recurringDataSource,
    quickTemplateDataSource: quickTemplateDataSource,
    categoryDataSource: categoryDataSource,
    exportService: exportService,
    storageService: storageService,
    backupService: backupService,
  ));

  // First frame paint marker
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('⏱ [t+${DateTime.now().millisecondsSinceEpoch - t0}ms] FIRST FRAME PAINTED');
  });
}

Widget _buildErrorApp() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Ứng dụng gặp lỗi khi khởi động.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng thử khởi động lại ứng dụng.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final TransactionLocalDataSource transactionDataSource;
  final BudgetLocalDataSource budgetDataSource;
  final BudgetSnapshotLocalDataSource budgetSnapshotDataSource;
  final BudgetPlanLocalDataSource budgetPlanDataSource;
  final RecurringLocalDataSource recurringDataSource;
  final QuickTemplateLocalDataSource quickTemplateDataSource;
  final CategoryLocalDataSource categoryDataSource;
  final ExportService exportService;
  final StorageService storageService;
  final BackupService backupService;

  const MyApp({
    super.key,
    required this.transactionDataSource,
    required this.budgetDataSource,
    required this.budgetSnapshotDataSource,
    required this.budgetPlanDataSource,
    required this.recurringDataSource,
    required this.quickTemplateDataSource,
    required this.categoryDataSource,
    required this.exportService,
    required this.storageService,
    required this.backupService,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('⏱ [Phase B] MyApp.build start (Provider tree create)');
    return MultiProvider(
      providers: [
        // ADR-0050 (P1 — reactive settings): app-config VM, placed first so
        // downstream VMs (CategoryVM, future BudgetVM proxy) có thể inject
        // qua context.read<AppSettingsViewModel>() thay direct SharedPreferences.
        ChangeNotifierProvider(
          create: (_) => AppSettingsViewModel(storageService)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryViewModel(categoryDataSource, budgetDataSource),
        ),
        ChangeNotifierProvider(
          create: (_) => ExpenseViewModel(
            transactionDataSource,
            exportService,
            categoryDataSource,
          ),
        ),
        ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>(
          create: (_) => BudgetViewModel(
            budgetDataSource,
            budgetSnapshotDataSource,
            budgetPlanDataSource,
            categoryDataSource,
            storageService,
          ),
          update: (_, expenseVM, budgetVM) => budgetVM!
            ..updateStats(expenseVM.stats),
        ),
        ChangeNotifierProvider(
          create: (_) => RecurringTransactionViewModel(
            recurringDataSource,
            transactionDataSource,
            categoryDataSource,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => QuickTemplateViewModel(quickTemplateDataSource),
        ),
        ChangeNotifierProvider(
          create: (context) => BackupViewModel(
            backupService,
            context.read<ExpenseViewModel>(),
            context.read<BudgetViewModel>(),
            context.read<RecurringTransactionViewModel>(),
            context.read<QuickTemplateViewModel>(),
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MonthlyReviewViewModel(
            transactionDataSource: transactionDataSource,
            budgetDataSource: budgetDataSource,
            budgetSnapshotDataSource: budgetSnapshotDataSource,
            recurringDataSource: recurringDataSource,
            categoryDataSource: categoryDataSource,
          ),
        ),
        // ADR-0055 (cold start perf): defer MonthlyPlanViewModel.load() from
        // ctor microtask → on-demand khi MonthlyPlanScreen.initState postFrame.
        // Save ~20-50ms cold start path.
        ChangeNotifierProvider(
          create: (_) => MonthlyPlanViewModel(
            budgetPlanDataSource: budgetPlanDataSource,
            budgetDataSource: budgetDataSource,
            budgetSnapshotDataSource: budgetSnapshotDataSource,
            transactionDataSource: transactionDataSource,
            categoryDataSource: categoryDataSource,
            storageService: storageService,
            builder: MonthlyBudgetPlanBuilder(),
            now: DateTime.now(),
          ),
        ),
        // ADR-0053 (Epic 4 — Weekly Review): 10th ChangeNotifier.
        // ProxyProvider<ExpenseVM> → on add/delete notify, weeklyVM.invalidate()
        // marks data stale → next load() recomputes. Mirror BudgetViewModel
        // pattern (ADR-0005) but weeklyVM doesn't need expense stats; only
        // needs dirty signal.
        // ADR-0057 (race fix 2026-06-16): drop ChangeNotifierProxyProvider.
        // Old pattern: update() fires on every weeklyVM.notify (cascade)
        // → re-calls invalidate() → re-notify → ... infinite micro-loop
        // where dirty=true blocks load() from completing. Replace with
        // plain ChangeNotifierProvider + manual listener on ExpenseVM
        // attached once in create. Listener calls invalidate() (no
        // notify) so cascade impossible.
        ChangeNotifierProvider<WeeklyReviewViewModel>(
          create: (context) {
            final weeklyVM = WeeklyReviewViewModel(
              transactionDataSource: transactionDataSource,
              budgetDataSource: budgetDataSource,
              recurringDataSource: recurringDataSource,
              categoryDataSource: categoryDataSource,
            );
            // Wire listener once. ExpenseVM notify on add/edit/delete
            // → mark stale. No notify needed (cascade guard).
            context.read<ExpenseViewModel>().addListener(weeklyVM.invalidate);
            return weeklyVM;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Quản Lý Chi Tiêu',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/database/database_helper.dart';
import 'data/datasources/sqlite_transaction_datasource.dart';
import 'data/datasources/sqlite_budget_datasource.dart';
import 'data/datasources/sqlite_recurring_datasource.dart';
import 'data/datasources/sqlite_quick_template_datasource.dart';
import 'data/datasources/transaction_local_datasource.dart';
import 'data/datasources/budget_local_datasource.dart';
import 'data/datasources/recurring_local_datasource.dart';
import 'data/datasources/quick_template_local_datasource.dart';
import 'data/migrations/shared_prefs_to_sqlite.dart';
import 'services/storage_service.dart';
import 'services/export_service.dart';
import 'services/backup_service.dart';
import 'viewmodels/expense_viewmodel.dart';
import 'viewmodels/budget_viewmodel.dart';
import 'viewmodels/recurring_viewmodel.dart';
import 'viewmodels/quick_template_viewmodel.dart';
import 'viewmodels/backup_viewmodel.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
        if (options.dsn?.isEmpty ?? true) {
          debugPrint('⚠️ SENTRY_DSN not set — crash reporting disabled');
          return;
        }
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

Future<void> _initApp() async {
  debugPrint('🚀 Initializing app...');

  // Initialize dependencies
  debugPrint('📦 Getting SharedPreferences...');
  final prefs = await SharedPreferences.getInstance();
  debugPrint('✅ SharedPreferences initialized');

  // Initialize StorageService for SharedPreferences
  final storageService = StorageService(prefs);

  debugPrint('💾 Setting up database...');
  final dbHelper = DatabaseHelper();
  final transactionDataSource = SqliteTransactionDataSource(dbHelper);
  debugPrint('✅ Database ready');

  debugPrint('🔄 Running migration...');
  final migrationService = MigrationService(dbHelper);
  await migrationService.migrate();
  debugPrint('✅ Migration done');

  debugPrint('📤 Setting up export service...');
  final exportService = ExportService();
  debugPrint('✅ Export service ready');

  debugPrint('💾 Setting up transaction data source...');
  debugPrint('✅ Transaction data source ready');

  debugPrint('💰 Setting up budget data source...');
  final budgetDataSource = SqliteBudgetDataSource(dbHelper);
  debugPrint('✅ Budget data source ready');

  debugPrint('🔄 Setting up recurring data source...');
  final recurringDataSource = SqliteRecurringDataSource(dbHelper);
  debugPrint('✅ Recurring data source ready');

  debugPrint('⚡ Setting up quick template data source...');
  final quickTemplateDataSource = SqliteQuickTemplateDataSource(dbHelper);
  debugPrint('✅ Quick template data source ready');

  debugPrint('📦 Setting up backup service...');
  final backupService = BackupService(
    transactionDataSource,
    budgetDataSource,
    recurringDataSource,
    quickTemplateDataSource,
    storageService,
    dbHelper,
  );
  debugPrint('✅ Backup service ready');

  debugPrint('Starting app...');
  runApp(MyApp(
    transactionDataSource: transactionDataSource,
    budgetDataSource: budgetDataSource,
    recurringDataSource: recurringDataSource,
    quickTemplateDataSource: quickTemplateDataSource,
    exportService: exportService,
    storageService: storageService,
    backupService: backupService,
  ));
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
  final RecurringLocalDataSource recurringDataSource;
  final QuickTemplateLocalDataSource quickTemplateDataSource;
  final ExportService exportService;
  final StorageService storageService;
  final BackupService backupService;

  const MyApp({
    super.key,
    required this.transactionDataSource,
    required this.budgetDataSource,
    required this.recurringDataSource,
    required this.quickTemplateDataSource,
    required this.exportService,
    required this.storageService,
    required this.backupService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ExpenseViewModel(transactionDataSource, exportService),
        ),
        ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>(
          create: (_) => BudgetViewModel(budgetDataSource, storageService),
          update: (_, expenseVM, budgetVM) => budgetVM!
            ..updateStats(expenseVM.stats),
        ),
        ChangeNotifierProvider(
          create: (_) => RecurringTransactionViewModel(recurringDataSource, transactionDataSource),
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

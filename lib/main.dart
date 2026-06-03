import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/database/database_helper.dart';
import 'data/datasources/sqlite_transaction_datasource.dart';
import 'data/datasources/budget_local_datasource.dart';
import 'data/datasources/sqlite_budget_datasource.dart';
import 'data/migrations/shared_prefs_to_sqlite.dart';
import 'services/storage_service.dart';
import 'services/export_service.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/transaction_repository_impl.dart';
import 'repositories/budget_repository.dart';
import 'repositories/budget_repository_impl.dart';
import 'viewmodels/expense_viewmodel.dart';
import 'viewmodels/budget_viewmodel.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('🚀 Initializing app...');

    // Initialize dependencies
    debugPrint('📦 Getting SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    debugPrint('✅ SharedPreferences initialized');

    // Keep StorageService for future settings use
    // ignore: unused_local_variable
    final storageService = StorageService(prefs);

    debugPrint('💾 Setting up database...');
    final dbHelper = DatabaseHelper();
    final dataSource = SqliteTransactionDataSource(dbHelper);
    debugPrint('✅ Database ready');

    debugPrint('🔄 Running migration...');
    final migrationService = MigrationService(dataSource);
    await migrationService.migrate();
    debugPrint('✅ Migration done');

    debugPrint('📤 Setting up export service...');
    final exportService = ExportService();
    debugPrint('✅ Export service ready');

    debugPrint('💾 Setting up repository...');
    final TransactionRepository repository = TransactionRepositoryImpl(dataSource);
    debugPrint('✅ Repository ready');

    debugPrint('💰 Setting up budget repository...');
    final BudgetLocalDataSource budgetDataSource = SqliteBudgetDataSource(dbHelper);
    final BudgetRepository budgetRepository = BudgetRepositoryImpl(budgetDataSource);
    debugPrint('✅ Budget repository ready');

    debugPrint('🎯 Starting app...');
    runApp(MyApp(
      repository: repository,
      budgetRepository: budgetRepository,
      exportService: exportService,
    ));
  } catch (e, stackTrace) {
    debugPrint('❌ Error during initialization: $e');
    debugPrint('📍 Stack trace: $stackTrace');
    
    // Fallback if initialization fails
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '❌ Error Initializing App',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stack: $stackTrace',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final TransactionRepository repository;
  final BudgetRepository budgetRepository;
  final ExportService exportService;

  const MyApp({
    super.key,
    required this.repository,
    required this.budgetRepository,
    required this.exportService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ExpenseViewModel(repository, exportService),
        ),
        ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>(
          create: (_) => BudgetViewModel(budgetRepository),
          update: (_, expenseVM, budgetVM) => budgetVM!..updateStats(expenseVM.stats),
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

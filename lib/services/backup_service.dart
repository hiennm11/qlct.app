import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/backup_data.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/recurring_repository.dart';
import 'storage_service.dart';

/// Result of import validation
class ImportResult {
  final bool isValid;
  final BackupData? data;
  final List<String> errors;

  const ImportResult._({required this.isValid, this.data, required this.errors});

  factory ImportResult.valid(BackupData data) =>
      ImportResult._(isValid: true, data: data, errors: const []);

  factory ImportResult.error(List<String> errors) =>
      ImportResult._(isValid: false, data: null, errors: errors);
}

/// Restore mode for backup restore
enum RestoreMode { merge, replace }

/// Result of a restore operation
class RestoreResult {
  final bool success;
  final int transactionsImported;
  final int budgetsImported;
  final int recurringsImported;
  final String? error;

  const RestoreResult({
    required this.success,
    required this.transactionsImported,
    required this.budgetsImported,
    required this.recurringsImported,
    this.error,
  });
}

/// Service for full backup and restore operations
class BackupService {
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;
  final RecurringRepository _recurringRepo;
  final StorageService _storageService;

  BackupService(
    this._transactionRepo,
    this._budgetRepo,
    this._recurringRepo,
    this._storageService,
  );

  /// Create a full backup payload from current app state
  Future<BackupData> createBackup() async {
    final transactions = await _transactionRepo.getAll();
    final budgets = await _budgetRepo.getAll();
    final recurrings = await _recurringRepo.getAll();
    final totalBudget = _storageService.loadValue<int>('total_budget') ?? 0;

    return BackupData(
      schemaVersion: currentSchemaVersion,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      appVersion: AppConstants.appVersion,
      totalBudget: totalBudget,
      transactions: transactions,
      budgets: budgets,
      recurringTransactions: recurrings,
    );
  }

  /// Serialize BackupData to a JSON-serializable Map with nested objects
  Map<String, dynamic> _toJsonMap(BackupData data) {
    return {
      'schemaVersion': data.schemaVersion,
      'exportedAt': data.exportedAt,
      'appVersion': data.appVersion,
      'totalBudget': data.totalBudget,
      'transactions': data.transactions.map((t) => t.toJson()).toList(),
      'budgets': data.budgets.map((b) => b.toJson()).toList(),
      'recurringTransactions':
          data.recurringTransactions.map((r) => r.toJson()).toList(),
    };
  }

  /// Export backup data to a JSON file
  Future<File> exportToJson(BackupData data) async {
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(_toJsonMap(data));
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'qlct-backup-$dateStr.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString, encoding: utf8);
    return file;
  }

  /// Share a backup file via system share sheet
  Future<void> shareBackup(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Sao lưu dữ liệu QLCT',
    );
  }

  /// Create backup, export to file, and share
  Future<File> createAndExportBackup() async {
    final data = await createBackup();
    final file = await exportToJson(data);
    await shareBackup(file);
    return file;
  }

  /// Open file picker to select a JSON backup file
  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    return File(result.files.single.path!);
  }

  /// Validate a backup JSON string
  ImportResult validate(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        return ImportResult.error(['File không phải là JSON object hợp lệ']);
      }

      final map = decoded;

      // Check schemaVersion
      if (map['schemaVersion'] is! int) {
        return ImportResult.error(
            ['Thiếu schemaVersion — file không đúng định dạng backup QLCT']);
      }

      final version = map['schemaVersion'] as int;
      if (version > currentSchemaVersion) {
        return ImportResult.error([
          'File được tạo bởi phiên bản app mới hơn (schema v$version). '
              'Vui lòng cập nhật app để khôi phục file này.'
        ]);
      }

      // Validate transactions array
      if (map['transactions'] != null &&
          map['transactions'] is! List) {
        return ImportResult.error(['"transactions" không phải là mảng']);
      }

      // Validate budgets array
      if (map['budgets'] != null && map['budgets'] is! List) {
        return ImportResult.error(['"budgets" không phải là mảng']);
      }

      // Validate recurringTransactions array
      if (map['recurringTransactions'] != null &&
          map['recurringTransactions'] is! List) {
        return ImportResult.error(
            ['"recurringTransactions" không phải là mảng']);
      }

      // Try to deserialize using the Freezed model
      try {
        final backupData = BackupData.fromJson(map);
        return ImportResult.valid(backupData);
      } catch (e, stack) {
        debugPrint('Backup parse error: $e\n$stack');
        return ImportResult.error([
          'Không thể đọc dữ liệu trong file: file có thể bị hỏng hoặc sai định dạng.'
        ]);
      }
    } on FormatException {
      return ImportResult.error(['File không phải là JSON hợp lệ']);
    } catch (e) {
      return ImportResult.error(['Lỗi không xác định: $e']);
    }
  }

  /// Restore data from a BackupData payload
  /// [mode] determines merge or replace behavior
  Future<RestoreResult> restore(BackupData data, RestoreMode mode) async {
    try {
      if (mode == RestoreMode.replace) {
        // Replace: clear all then insert
        await _transactionRepo.clearAll();

        // Delete all recurrings individually (no clearAll/deleteAll on this repo)
        final existingRecurrings = await _recurringRepo.getAll();
        for (final r in existingRecurrings) {
          await _recurringRepo.delete(r.id);
        }

        // For budgets, delete one by one via getAll
        final existingBudgets = await _budgetRepo.getAll();
        for (final b in existingBudgets) {
          await _budgetRepo.delete(b.id);
        }
      }

      // Prepare lists
      final transactions = data.transactions;
      final budgets = data.budgets;
      final recurrings = data.recurringTransactions;

      int txImported = 0;
      int bImported = 0;
      int rImported = 0;

      if (mode == RestoreMode.merge) {
        // Merge: only insert records with new IDs
        final existingTxIds = (await _transactionRepo.getAll())
            .map((t) => t.id)
            .toSet();
        final existingBIds =
            (await _budgetRepo.getAll()).map((b) => b.id).toSet();
        final existingRIds = (await _recurringRepo.getAll())
            .map((r) => r.id)
            .toSet();

        final newTransactions =
            transactions.where((t) => !existingTxIds.contains(t.id)).toList();
        final newBudgets =
            budgets.where((b) => !existingBIds.contains(b.id)).toList();
        final newRecurrings =
            recurrings.where((r) => !existingRIds.contains(r.id)).toList();

        if (newTransactions.isNotEmpty) {
          await _transactionRepo.bulkAdd(newTransactions);
        }
        txImported = newTransactions.length;

        if (newBudgets.isNotEmpty) {
          await _budgetRepo.bulkUpsert(newBudgets);
        }
        bImported = newBudgets.length;

        if (newRecurrings.isNotEmpty) {
          await _recurringRepo.bulkInsert(newRecurrings);
        }
        rImported = newRecurrings.length;

        // Only overwrite totalBudget if it's currently 0
        if (_storageService.loadValue<int>('total_budget') == 0 ||
            _storageService.loadValue<int>('total_budget') == null) {
          _storageService.saveValue('total_budget', data.totalBudget);
        }
      } else {
        // Replace mode: insert everything
        if (transactions.isNotEmpty) {
          await _transactionRepo.bulkAdd(transactions);
        }
        txImported = transactions.length;

        if (budgets.isNotEmpty) {
          await _budgetRepo.bulkUpsert(budgets);
        }
        bImported = budgets.length;

        if (recurrings.isNotEmpty) {
          await _recurringRepo.bulkInsert(recurrings);
        }
        rImported = recurrings.length;

        // Overwrite totalBudget
        _storageService.saveValue('total_budget', data.totalBudget);
      }

      return RestoreResult(
        success: true,
        transactionsImported: txImported,
        budgetsImported: bImported,
        recurringsImported: rImported,
      );
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      return RestoreResult(
        success: false,
        transactionsImported: 0,
        budgetsImported: 0,
        recurringsImported: 0,
        error: 'Lỗi khi khôi phục dữ liệu: $e',
      );
    }
  }

  /// Generate sample data for testing (hidden dev feature)
  Future<BackupData> generateSampleData() async {
    final uuid = const Uuid();
    final now = DateTime.now();
    final rng = DateTime.now().millisecondsSinceEpoch.remainder(100);

    // Generate 20 transactions across 5 categories, spread over 30 days
    final transactions = <Transaction>[];
    final categories = ['Ăn ngoài', 'Cà phê', 'Mua online', 'Giải trí', 'Khác'];
    final emojis = ['🍜', '☕', '🛒', '🎬', '📌'];
    final amounts = [
      [30000, 50000, 75000, 120000, 45000], // Ăn ngoài
      [15000, 20000, 25000, 35000, 18000], // Cà phê
      [50000, 150000, 250000, 75000, 350000], // Mua online
      [50000, 80000, 120000, 45000, 60000], // Giải trí
      [20000, 50000, 100000, 35000, 75000], // Khác
    ];

    for (int i = 0; i < 20; i++) {
      final catIndex = i % categories.length;
      final amountIndex = (i + rng) % amounts[catIndex].length;
      final dayOffset = (20 - i) ~/ 2; // spread over recent days
      final date = now.subtract(Duration(days: dayOffset));

      transactions.add(Transaction(
        id: uuid.v4(),
        amount: amounts[catIndex][amountIndex],
        category: categories[catIndex],
        emoji: emojis[catIndex],
        date: DateTime(date.year, date.month, date.day,
            (8 + i % 14).clamp(0, 23), (i * 7 % 60)),
        note: i % 3 == 0 ? 'Ghi chú mẫu #${i + 1}' : '',
      ));
    }

    // Generate 3 budgets
    final budgets = <Budget>[
      Budget(
        id: uuid.v4(),
        categoryName: 'Ăn ngoài',
        monthlyLimit: 3000000,
        alertThreshold: 80,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      Budget(
        id: uuid.v4(),
        categoryName: 'Cà phê',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      Budget(
        id: uuid.v4(),
        categoryName: 'Mua online',
        monthlyLimit: 2000000,
        alertThreshold: 80,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ];

    // Generate 2 recurring transactions
    final recurrings = <RecurringTransaction>[
      RecurringTransaction(
        id: uuid.v4(),
        categoryName: 'Subscription',
        amount: 200000,
        note: 'GitHub Copilot',
        frequency: 'monthly',
        nextRunAt: now.add(const Duration(days: 25)),
        isActive: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      RecurringTransaction(
        id: uuid.v4(),
        categoryName: 'Nhà (Điện, nước, wifi)',
        amount: 3300000,
        note: 'Tiền nhà hàng tháng',
        frequency: 'monthly',
        nextRunAt: now.add(const Duration(days: 10)),
        isActive: true,
        createdAt: now.subtract(const Duration(days: 120)),
      ),
    ];

    return BackupData(
      schemaVersion: currentSchemaVersion,
      exportedAt: now.toUtc().toIso8601String(),
      appVersion: AppConstants.appVersion,
      totalBudget: 15000000,
      transactions: transactions,
      budgets: budgets,
      recurringTransactions: recurrings,
    );
  }
}

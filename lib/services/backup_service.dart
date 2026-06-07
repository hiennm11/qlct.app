import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../data/database/database_helper.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/recurring_local_datasource.dart';
import '../data/datasources/quick_template_local_datasource.dart';
import '../data/mappers/transaction_row_mapper.dart';
import '../data/mappers/budget_row_mapper.dart';
import '../data/mappers/recurring_row_mapper.dart';
import '../data/mappers/quick_template_mapper.dart';
import '../models/backup_data.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/quick_template.dart';
import 'storage_service.dart';

/// Thrown by [BackupService.pickBackupFile] when the selected file exceeds
/// the 50MB import limit. Surfaces a user-friendly error to the viewmodel.
class FileTooLargeException implements Exception {
  final String message;
  const FileTooLargeException(this.message);
  @override
  String toString() => message;
}

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
  final int quickTemplatesImported;
  final String? error;

  const RestoreResult({
    required this.success,
    required this.transactionsImported,
    required this.budgetsImported,
    required this.recurringsImported,
    required this.quickTemplatesImported,
    this.error,
  });
}

/// Service for full backup and restore operations
class BackupService {
  final TransactionLocalDataSource _transactionDataSource;
  final BudgetLocalDataSource _budgetDataSource;
  final RecurringLocalDataSource _recurringDataSource;
  final QuickTemplateLocalDataSource _quickTemplateDataSource;
  final StorageService _storageService;
  final DatabaseHelper _dbHelper;

  BackupService(
    this._transactionDataSource,
    this._budgetDataSource,
    this._recurringDataSource,
    this._quickTemplateDataSource,
    this._storageService,
    this._dbHelper,
  );

  /// Create a full backup payload from current app state
  Future<BackupData> createBackup() async {
    final transactions = await _transactionDataSource.getAll();
    final budgets = await _budgetDataSource.getAll();
    final recurrings = await _recurringDataSource.getAll();
    final quickTemplates = await _quickTemplateDataSource.getAll();
    final totalBudget = _storageService.loadValue<int>('total_budget') ?? 0;

    return BackupData(
      schemaVersion: currentSchemaVersion,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      appVersion: AppConstants.appVersion,
      totalBudget: totalBudget,
      transactions: transactions,
      budgets: budgets,
      recurringTransactions: recurrings,
      quickTemplates: quickTemplates,
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
      'quickTemplates':
          data.quickTemplates.map((q) => q.toJson()).toList(),
    };
  }

  /// Export backup data to a JSON file
  Future<File> exportToJson(BackupData data) async {
    final jsonString = const JsonEncoder().convert(_toJsonMap(data));
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

    final file = File(result.files.single.path!);

    // Guard: max 50MB. A malicious or accidental oversized JSON would otherwise
    // be fully read into memory and could OOM the app.
    const maxSize = 50 * 1024 * 1024;
    final size = await file.length();
    if (size > maxSize) {
      throw FileTooLargeException(
        'File quá lớn (${(size / 1024 / 1024).toStringAsFixed(1)}MB). '
        'Giới hạn tối đa: 50MB.',
      );
    }

    return file;
  }

  /// Validate a backup file using streaming JSON parse.
  /// Reads incrementally instead of loading entire file into memory.
  /// [file] must have passed the 50MB size guard from [pickBackupFile].
  Future<ImportResult> validateFile(File file) async {
    try {
      final stream = file
          .openRead()
          .transform(utf8.decoder)
          .transform(json.decoder);
      final dynamic decoded = await stream.first;

      if (decoded is! Map<String, dynamic>) {
        return ImportResult.error(
            ['File không phải là JSON object hợp lệ']);
      }

      return _validateDecoded(decoded);
    } on FormatException catch (e) {
      return ImportResult.error(['File không phải là JSON hợp lệ: ${e.message}']);
    } catch (e) {
      return ImportResult.error(['Lỗi không xác định: $e']);
    }
  }

  /// Core validation logic for a decoded JSON map.
  /// Extracted from [validate] to enable reuse by [validateFile].
  ImportResult _validateDecoded(Map<String, dynamic> map) {
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
    if (map['transactions'] != null && map['transactions'] is! List) {
      return ImportResult.error(['"transactions" không phải là mảng']);
    }

    // Validate budgets array
    if (map['budgets'] != null && map['budgets'] is! List) {
      return ImportResult.error(['"budgets" không phải là mảng']);
    }

    // Validate recurringTransactions array
    if (map['recurringTransactions'] != null &&
        map['recurringTransactions'] is! List) {
      return ImportResult.error(['"recurringTransactions" không phải là mảng']);
    }

    // Validate quickTemplates array (ADR-0019)
    if (map['quickTemplates'] != null && map['quickTemplates'] is! List) {
      return ImportResult.error(['"quickTemplates" không phải là mảng']);
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
  }

  /// Validate a backup JSON string
  ImportResult validate(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        return ImportResult.error(['File không phải là JSON object hợp lệ']);
      }

      return _validateDecoded(decoded);
    } on FormatException {
      return ImportResult.error(['File không phải là JSON hợp lệ']);
    } catch (e) {
      return ImportResult.error(['Lỗi không xác định: $e']);
    }
  }

  /// Restore data from a BackupData payload
  /// [mode] determines merge or replace behavior.
  ///
  /// Replace mode is fully atomic: all DELETEs and INSERTs happen in one
  /// SQLite transaction. If any insert fails the entire operation rolls back.
  ///
  /// Merge mode uses INSERT OR IGNORE so existing rows (by PRIMARY KEY) are
  /// skipped without loading any IDs into Dart memory.
  Future<RestoreResult> restore(BackupData data, RestoreMode mode) async {
    try {
      final transactions = data.transactions;
      final budgets = data.budgets;
      final recurrings = data.recurringTransactions;
      final quickTemplates = data.quickTemplates;

      // Hoist SharedPreferences read OUTSIDE the DB transaction to avoid
      // stalling the transaction with a sync I/O call.
      final currentTotalBudget = _storageService.loadValue<int>('total_budget');

      return await _dbHelper.runInTransaction((txn) async {
        if (mode == RestoreMode.replace) {
          // Atomic clear: delete all within the same transaction as the inserts.
          // If the insert phase fails, this delete is also rolled back.
          await txn.delete('transactions');
          await txn.delete('budgets');
          await txn.delete('recurring_transactions');
          await txn.delete('quick_templates');
        }

        int txImported = 0;
        int bImported = 0;
        int rImported = 0;
        int qtImported = 0;

        if (mode == RestoreMode.merge) {
          // Use INSERT OR IGNORE — SQLite PRIMARY KEY constraint handles
          // deduplication. No O(N) Dart-side ID loading.
          if (transactions.isNotEmpty) {
            final batch = txn.batch();
            for (final t in transactions) {
              batch.insert('transactions', _transactionToMap(t),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            final results = await batch.commit(noResult: false);
            txImported = results.whereType<int>().where((r) => r > 0).length;
          }

          if (budgets.isNotEmpty) {
            final batch = txn.batch();
            for (final b in budgets) {
              batch.insert('budgets', _budgetToMap(b),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            final results = await batch.commit(noResult: false);
            bImported = results.whereType<int>().where((r) => r > 0).length;
          }

          if (recurrings.isNotEmpty) {
            final batch = txn.batch();
            for (final r in recurrings) {
              batch.insert('recurring_transactions', _recurringToMap(r),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            final results = await batch.commit(noResult: false);
            rImported = results.whereType<int>().where((r) => r > 0).length;
          }

          if (quickTemplates.isNotEmpty) {
            final batch = txn.batch();
            for (final q in quickTemplates) {
              batch.insert('quick_templates', _quickTemplateToMap(q),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            final results = await batch.commit(noResult: false);
            qtImported = results.whereType<int>().where((r) => r > 0).length;
          }

          // Use the hoisted value — no SharedPreferences call inside txn
          if (currentTotalBudget == 0 || currentTotalBudget == null) {
            _storageService.saveValue('total_budget', data.totalBudget);
          }
        } else {
          // Replace mode: insert everything (table already cleared above).
          if (transactions.isNotEmpty) {
            final batch = txn.batch();
            for (final t in transactions) {
              batch.insert('transactions', _transactionToMap(t));
            }
            await batch.commit(noResult: true);
            txImported = transactions.length;
          }

          if (budgets.isNotEmpty) {
            final batch = txn.batch();
            for (final b in budgets) {
              batch.insert('budgets', _budgetToMap(b));
            }
            await batch.commit(noResult: true);
            bImported = budgets.length;
          }

          if (recurrings.isNotEmpty) {
            final batch = txn.batch();
            for (final r in recurrings) {
              batch.insert('recurring_transactions', _recurringToMap(r));
            }
            await batch.commit(noResult: true);
            rImported = recurrings.length;
          }

          if (quickTemplates.isNotEmpty) {
            final batch = txn.batch();
            for (final q in quickTemplates) {
              batch.insert('quick_templates', _quickTemplateToMap(q));
            }
            await batch.commit(noResult: true);
            qtImported = quickTemplates.length;
          }

          _storageService.saveValue('total_budget', data.totalBudget);
        }

        return RestoreResult(
          success: true,
          transactionsImported: txImported,
          budgetsImported: bImported,
          recurringsImported: rImported,
          quickTemplatesImported: qtImported,
        );
      });
    } on FileTooLargeException {
      rethrow;
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      return RestoreResult(
        success: false,
        transactionsImported: 0,
        budgetsImported: 0,
        recurringsImported: 0,
        quickTemplatesImported: 0,
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

    // Generate 3 quick templates (ADR-0019)
    final quickTemplates = <QuickTemplate>[
      QuickTemplate(
        id: uuid.v4(),
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        note: '',
        emoji: '🍜',
        isPinned: true,
        usageCount: 12,
        lastUsedAt: now.subtract(const Duration(hours: 3)),
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      QuickTemplate(
        id: uuid.v4(),
        title: 'Cà phê sáng',
        amount: 25000,
        categoryName: 'Cà phê',
        note: '',
        emoji: '☕',
        isPinned: false,
        usageCount: 8,
        lastUsedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      QuickTemplate(
        id: uuid.v4(),
        title: 'Shopee',
        amount: 120000,
        categoryName: 'Mua online',
        note: '',
        emoji: '🛒',
        isPinned: false,
        usageCount: 2,
        lastUsedAt: null,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
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
      quickTemplates: quickTemplates,
    );
  }

  // -------------------------------------------------------------------------
  // Row-to-map helpers — mirror the schema defined in DatabaseHelper.
  // Transactions table: date=TEXT(ISO), created_at=INTEGER(ms)
  // Budgets table:      created_at=INTEGER(ms)
  // Recurring table:    next_run_at=TEXT(ISO), is_active=INTEGER(0/1),
  //                     created_at=TEXT(ISO) — NOT millisecondsSinceEpoch.
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Row mappers: delegate to shared top-level functions from data/mappers/.
  // -------------------------------------------------------------------------

  Map<String, dynamic> _transactionToMap(Transaction t) =>
      transactionToRow(t);

  Map<String, dynamic> _budgetToMap(Budget b) => budgetToRow(b);

  Map<String, dynamic> _recurringToMap(RecurringTransaction r) =>
      recurringToRow(r);

  Map<String, dynamic> _quickTemplateToMap(QuickTemplate q) =>
      quickTemplateToRow(q);
}

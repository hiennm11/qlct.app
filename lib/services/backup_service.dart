import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../data/database/database_helper.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/budget_snapshot_local_datasource.dart';
import '../data/datasources/budget_plan_local_datasource.dart';
import '../data/datasources/recurring_local_datasource.dart';
import '../data/datasources/quick_template_local_datasource.dart';
import '../data/datasources/category_local_datasource.dart';
import '../data/mappers/transaction_row_mapper.dart';
import '../data/mappers/budget_row_mapper.dart';
import '../data/mappers/budget_snapshot_row_mapper.dart';
import '../data/mappers/budget_plan_row_mapper.dart';
import '../data/mappers/recurring_row_mapper.dart';
import '../data/mappers/quick_template_mapper.dart';
import '../data/mappers/category_row_mapper.dart';
import '../models/backup_data.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/budget_snapshot.dart';
import '../models/budget_plan.dart';
import '../models/recurring_transaction.dart';
import '../models/quick_template.dart';
import '../models/category.dart';
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

/// Aggregate count of user-data rows. ADR-0023 §8: used by destructive-action
/// preview dialogs to show how many rows will be cleared.
@immutable
class CurrentCounts {
  final int transactionCount;
  final int budgetCount;
  final int recurringCount;
  final int quickTemplateCount;
  final int budgetSnapshotCount;
  final int budgetPlanCount;
  final int budgetPlanItemCount;
  // ADR-0027 §13: category count for destructive previews.
  final int categoryCount;

  const CurrentCounts({
    required this.transactionCount,
    required this.budgetCount,
    required this.recurringCount,
    required this.quickTemplateCount,
    required this.budgetSnapshotCount,
    required this.budgetPlanCount,
    required this.budgetPlanItemCount,
    required this.categoryCount,
  });

  /// True when no user data exists.
  bool get isEmpty =>
      transactionCount == 0 &&
      budgetCount == 0 &&
      recurringCount == 0 &&
      quickTemplateCount == 0 &&
      budgetSnapshotCount == 0 &&
      budgetPlanCount == 0 &&
      budgetPlanItemCount == 0 &&
      categoryCount == 0;

  /// Sum of all counts.
  int get total =>
      transactionCount +
      budgetCount +
      recurringCount +
      quickTemplateCount +
      budgetSnapshotCount +
      budgetPlanCount +
      budgetPlanItemCount +
      categoryCount;

  @override
  String toString() =>
      'CurrentCounts(tx=$transactionCount, b=$budgetCount, '
      'r=$recurringCount, qt=$quickTemplateCount, '
      'bs=$budgetSnapshotCount, bp=$budgetPlanCount, '
      'bpi=$budgetPlanItemCount, cat=$categoryCount)';
}

/// Result of a restore operation
class RestoreResult {
  final bool success;
  final int transactionsImported;
  final int budgetsImported;
  final int recurringsImported;
  final int quickTemplatesImported;
  final int budgetSnapshotsImported;
  final int budgetPlansImported;
  final int budgetPlanItemsImported;
  // ADR-0027 §13: category restore result.
  final int categoriesImported;
  final String? error;

  const RestoreResult({
    required this.success,
    required this.transactionsImported,
    required this.budgetsImported,
    required this.recurringsImported,
    required this.quickTemplatesImported,
    required this.budgetSnapshotsImported,
    required this.budgetPlansImported,
    required this.budgetPlanItemsImported,
    required this.categoriesImported,
    this.error,
  });
}

/// Thrown by [BackupService.clearAllUserData] when totalBudget reset fails
/// after the DB transaction succeeded. DB rows are gone; the caller should
/// report this to the user.
class ClearDataPartialFailure implements Exception {
  final String message;
  const ClearDataPartialFailure(this.message);
  @override
  String toString() => message;
}

/// Service for full backup and restore operations
/// ADR-0025: Monthly Budget Snapshots
/// ADR-0026: Monthly Budget Planning (schema v5)
/// ADR-0027 §13: Category catalog (schema v6)
class BackupService {
  final TransactionLocalDataSource _transactionDataSource;
  final BudgetLocalDataSource _budgetDataSource;
  final BudgetSnapshotLocalDataSource _budgetSnapshotDataSource;
  final BudgetPlanLocalDataSource _budgetPlanDataSource;
  final RecurringLocalDataSource _recurringDataSource;
  final QuickTemplateLocalDataSource _quickTemplateDataSource;
  // ADR-0027 §13: category catalog source of truth.
  final CategoryLocalDataSource _categoryDataSource;
  final StorageService _storageService;
  final DatabaseHelper _dbHelper;

  BackupService(
    this._transactionDataSource,
    this._budgetDataSource,
    this._budgetSnapshotDataSource,
    this._budgetPlanDataSource,
    this._recurringDataSource,
    this._quickTemplateDataSource,
    this._categoryDataSource,
    this._storageService,
    this._dbHelper,
  );

  /// Create a full backup payload from current app state
  Future<BackupData> createBackup() async {
    final transactions = await _transactionDataSource.getAll();
    final budgets = await _budgetDataSource.getAll();
    final recurrings = await _recurringDataSource.getAll();
    final quickTemplates = await _quickTemplateDataSource.getAll();
    final budgetSnapshots = await _budgetSnapshotDataSource.getAll();
    final budgetPlans = await _budgetPlanDataSource.getAllPlans();
    final budgetPlanItems = await _budgetPlanDataSource.getAllItems();
    final categories = await _categoryDataSource.getAll();
    final totalBudget = _storageService.loadValue<int>('total_budget') ?? 0;

    return BackupData(
      appId: backupAppId,
      schemaVersion: currentSchemaVersion,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      appVersion: AppConstants.appVersion,
      totalBudget: totalBudget,
      transactions: transactions,
      budgets: budgets,
      recurringTransactions: recurrings,
      quickTemplates: quickTemplates,
      budgetSnapshots: budgetSnapshots,
      budgetPlans: budgetPlans,
      budgetPlanItems: budgetPlanItems,
      categories: categories,
    );
  }

/// Serialize BackupData to a JSON-serializable Map with nested objects.
/// Field order is stable per ADR-0023 §3 / ADR-0025 §7 / ADR-0026 §7 /
/// ADR-0027 §13 to make diffs/inspect/test snapshots easier. Model.toJson()
/// is not used here on purpose. Exposed publicly for test coverage of the
/// production serialization path.
Map<String, dynamic> toJsonMap(BackupData data) {
  return {
    'appId': data.appId,
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
    'budgetSnapshots':
        data.budgetSnapshots.map((s) => s.toJson()).toList(),
    'budgetPlans':
        data.budgetPlans.map((p) => p.toJson()).toList(),
    'budgetPlanItems':
        data.budgetPlanItems.map((i) => i.toJson()).toList(),
    'categories':
        data.categories.map((c) => c.toJson()).toList(),
  };
}

  /// Export backup data to a JSON file
  Future<File> exportToJson(BackupData data) async {
    final jsonString = const JsonEncoder().convert(toJsonMap(data));
    final directory = await getApplicationDocumentsDirectory();
    final fileName = generateBackupFilename();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString, encoding: utf8);
    return file;
  }

  /// Generate a backup filename for the current timestamp.
  /// Exposed publicly for test coverage without requiring path_provider mocking.
  static String generateBackupFilename() {
    final dateStr = DateFormat('yyyy-MM-dd-HHmmss').format(DateTime.now());
    return 'qlct-backup-$dateStr.json';
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

    // ADR-0023 §2: v3+ requires appId == "qlct.app"
    if (version >= 3) {
      final fileAppId = map['appId'] as String?;
      if (fileAppId == null || fileAppId.isEmpty) {
        return ImportResult.error([
          'File backup thiếu appId — định dạng không hợp lệ cho schema v$version.'
        ]);
      }
      if (fileAppId != backupAppId) {
        return ImportResult.error([
          'File backup không thuộc ứng dụng này (appId không khớp).'
        ]);
      }
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

    // Validate budgetSnapshots array (ADR-0025)
    if (map['budgetSnapshots'] != null && map['budgetSnapshots'] is! List) {
      return ImportResult.error(['"budgetSnapshots" không phải là mảng']);
    }

    // Validate budgetPlans array (ADR-0026)
    if (map['budgetPlans'] != null && map['budgetPlans'] is! List) {
      return ImportResult.error(['"budgetPlans" không phải là mảng']);
    }

    // Validate budgetPlanItems array (ADR-0026)
    if (map['budgetPlanItems'] != null && map['budgetPlanItems'] is! List) {
      return ImportResult.error(['"budgetPlanItems" không phải là mảng']);
    }

    // Validate categories array (ADR-0027 §13)
    if (map['categories'] != null && map['categories'] is! List) {
      return ImportResult.error(['"categories" không phải là mảng']);
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
  /// totalBudget is written AFTER the transaction commits (SharedPreferences
  /// is outside SQLite transactions). Failure to write totalBudget is caught
  /// and reported, but does not fail the operation since DB work is done.
  ///
  /// Merge mode uses INSERT OR IGNORE so existing rows (by PRIMARY KEY) are
  /// skipped without loading any IDs into Dart memory.
  ///
  /// ADR-0027 §13 category restore:
  /// - Merge: last-write-wins by `updatedAt` (insert if missing, update if
  ///   backup.updatedAt > current.updatedAt, else keep current).
  /// - Replace: clear categories + insert backup categories. If backup has
  ///   empty/missing categories, seed defaults via INSERT OR IGNORE so the
  ///   app never ends up category-empty.
  /// - Old backups v1-v5: missing `categories` field → after restore, if
  ///   the category table is empty, seed defaults (ADR-0027 §13).
  Future<RestoreResult> restore(BackupData data, RestoreMode mode) async {
    String? totalBudgetError;
    try {
      final transactions = data.transactions;
      final budgets = data.budgets;
      final recurrings = data.recurringTransactions;
      final quickTemplates = data.quickTemplates;
      final budgetSnapshots = data.budgetSnapshots;
      final budgetPlans = data.budgetPlans;
      final budgetPlanItems = data.budgetPlanItems;
      final categories = data.categories;
      final hasCategoriesInBackup = categories.isNotEmpty;

      // Hoist SharedPreferences read OUTSIDE the DB transaction to avoid
      // stalling the transaction with a sync I/O call.
      final currentTotalBudget = _storageService.loadValue<int>('total_budget');

      final result = await _dbHelper.runInTransaction((txn) async {
        if (mode == RestoreMode.replace) {
          // Atomic clear: delete all within the same transaction as the inserts.
          // If the insert phase fails, this delete is also rolled back.
          // ADR-0025 §7: include budget_snapshots in replace/clear-all
          // ADR-0026: include budget_plans + budget_plan_items
          // ADR-0027 §13: include categories
          await txn.delete('transactions');
          await txn.delete('budgets');
          await txn.delete('recurring_transactions');
          await txn.delete('quick_templates');
          await txn.delete('budget_snapshots');
          await txn.delete('budget_plan_items'); // ADR-0026
          await txn.delete('budget_plans'); // ADR-0026
          await txn.delete('categories'); // ADR-0027
        }

        int txImported = 0;
        int bImported = 0;
        int rImported = 0;
        int qtImported = 0;
        int bsImported = 0;
        int bpImported = 0;
        int bpiImported = 0;
        int catImported = 0;

        if (mode == RestoreMode.merge) {
          // Use INSERT OR IGNORE — SQLite PRIMARY KEY constraint handles
          // deduplication. Imported count = only new items (skipped dups not
          // counted), matching test expectations for "new X imported".
          if (transactions.isNotEmpty) {
            // Snapshot pre-existing IDs so we can count only new inserts.
            final preIds = (await txn.query('transactions', columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            final batch = txn.batch();
            for (final t in transactions) {
              batch.insert('transactions', _transactionToMap(t),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            final postIds = (await txn.query('transactions', columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            txImported = postIds.difference(preIds)
                .where((id) => transactions.any((t) => t.id == id))
                .length;
          }

          if (budgets.isNotEmpty) {
            final preIds = (await txn.query('budgets', columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            final batch = txn.batch();
            for (final b in budgets) {
              batch.insert('budgets', _budgetToMap(b),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            final postIds = (await txn.query('budgets', columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            bImported = postIds.difference(preIds)
                .where((id) => budgets.any((b) => b.id == id))
                .length;
          }

          if (recurrings.isNotEmpty) {
            final preIds = (await txn.query('recurring_transactions',
                    columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            final batch = txn.batch();
            for (final r in recurrings) {
              batch.insert('recurring_transactions', _recurringToMap(r),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            final postIds = (await txn.query('recurring_transactions',
                    columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            rImported = postIds.difference(preIds)
                .where((id) => recurrings.any((r) => r.id == id))
                .length;
          }

          if (quickTemplates.isNotEmpty) {
            final preIds = (await txn.query('quick_templates', columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            final batch = txn.batch();
            for (final q in quickTemplates) {
              batch.insert('quick_templates', _quickTemplateToMap(q),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            final postIds = (await txn.query('quick_templates', columns: ['id']))
                .map((r) => r['id'] as String)
                .toSet();
            qtImported = postIds.difference(preIds)
                .where((id) => quickTemplates.any((q) => q.id == id))
                .length;
          }

          // ADR-0025 §7: INSERT OR IGNORE via composite PK for budget_snapshots
          if (budgetSnapshots.isNotEmpty) {
            final batch = txn.batch();
            for (final s in budgetSnapshots) {
              batch.insert('budget_snapshots', _budgetSnapshotToMap(s),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            bsImported = budgetSnapshots.length;
          }

          // ADR-0026: INSERT OR IGNORE via primary key for budget_plans
          if (budgetPlans.isNotEmpty) {
            final batch = txn.batch();
            for (final p in budgetPlans) {
              batch.insert('budget_plans', _budgetPlanToMap(p),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            bpImported = budgetPlans.length;
          }

          // ADR-0026: INSERT OR IGNORE via composite PK for budget_plan_items
          if (budgetPlanItems.isNotEmpty) {
            final batch = txn.batch();
            for (final i in budgetPlanItems) {
              batch.insert('budget_plan_items', _budgetPlanItemToMap(i),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            bpiImported = budgetPlanItems.length;
          }

          // ADR-0027 §13: category merge — last-write-wins by updatedAt.
          // We fetch current rows, then for each backup category either
          // insert (when id missing) or update (when backup is newer) or
          // keep current (when backup is older). Row-by-row is acceptable
          // for the v6 schema since category count is small (~11-50).
          if (categories.isNotEmpty) {
            final currentRows = await txn.query('categories',
                columns: ['id', 'updated_at']);
            final currentById = <String, int>{
              for (final r in currentRows) r['id'] as String: r['updated_at'] as int,
            };
            for (final c in categories) {
              final backupUpdated = c.updatedAt.millisecondsSinceEpoch;
              final currentUpdated = currentById[c.id];
              if (currentUpdated == null) {
                await txn.insert('categories', _categoryToMap(c),
                    conflictAlgorithm: ConflictAlgorithm.replace);
                catImported++;
              } else if (backupUpdated > currentUpdated) {
                await txn.update('categories', _categoryToMap(c),
                    where: 'id = ?', whereArgs: [c.id]);
                catImported++;
              }
              // else: current is newer, keep as-is.
            }
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

          if (budgetSnapshots.isNotEmpty) {
            final batch = txn.batch();
            for (final s in budgetSnapshots) {
              batch.insert('budget_snapshots', _budgetSnapshotToMap(s));
            }
            await batch.commit(noResult: true);
            bsImported = budgetSnapshots.length;
          }

          // ADR-0026: plans first (FK ordering), then items
          if (budgetPlans.isNotEmpty) {
            for (final p in budgetPlans) {
              await txn.insert('budget_plans', _budgetPlanToMap(p));
            }
            bpImported = budgetPlans.length;
          }

          if (budgetPlanItems.isNotEmpty) {
            for (final i in budgetPlanItems) {
              await txn.insert('budget_plan_items', _budgetPlanItemToMap(i));
            }
            bpiImported = budgetPlanItems.length;
          }

          // ADR-0027 §13: replace categories with backup contents.
          if (categories.isNotEmpty) {
            final batch = txn.batch();
            for (final c in categories) {
              batch.insert('categories', _categoryToMap(c));
            }
            await batch.commit(noResult: true);
            catImported = categories.length;
          }
        }

        // ADR-0027 §13: if backup had no categories (v1-v5 OR replace-empty),
        // and the categories table is now empty, seed defaults via INSERT OR
        // IGNORE so the app is never left in a category-less state.
        if (!hasCategoriesInBackup) {
          final existing = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM categories')) ??
              0;
          if (existing == 0) {
            final defaults = seedCategories;
            final batch = txn.batch();
            for (final c in defaults) {
              batch.insert('categories', _categoryToMap(c),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            await batch.commit(noResult: true);
            catImported = defaults.length;
          }
        }

        return RestoreResult(
          success: true,
          transactionsImported: txImported,
          budgetsImported: bImported,
          recurringsImported: rImported,
          quickTemplatesImported: qtImported,
          budgetSnapshotsImported: bsImported,
          budgetPlansImported: bpImported,
          budgetPlanItemsImported: bpiImported,
          categoriesImported: catImported,
        );
      });

      // DB transaction committed. Now write totalBudget (outside SQLite txn).
      // Failure here is reported but does not fail the overall operation
      // (DB work is already committed; SharedPreferences is separate).
      try {
        if (mode == RestoreMode.merge) {
          if (currentTotalBudget == 0 || currentTotalBudget == null) {
            await _storageService.saveValue('total_budget', data.totalBudget);
          }
        } else {
          await _storageService.saveValue('total_budget', data.totalBudget);
        }
      } catch (e) {
        debugPrint('totalBudget save failed: $e');
        totalBudgetError =
            'Không lưu được tổng ngân sách (totalBudget). Dữ liệu khác đã khôi phục thành công.';
      }

      if (totalBudgetError != null) {
        return RestoreResult(
          success: true,
          transactionsImported: result.transactionsImported,
          budgetsImported: result.budgetsImported,
          recurringsImported: result.recurringsImported,
          quickTemplatesImported: result.quickTemplatesImported,
          budgetSnapshotsImported: result.budgetSnapshotsImported,
          budgetPlansImported: result.budgetPlansImported,
          budgetPlanItemsImported: result.budgetPlanItemsImported,
          categoriesImported: result.categoriesImported,
          error: totalBudgetError,
        );
      }

      return result;
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
        budgetSnapshotsImported: 0,
        budgetPlansImported: 0,
        budgetPlanItemsImported: 0,
        categoriesImported: 0,
        error: 'Lỗi khi khôi phục dữ liệu: $e',
      );
    }
  }

  /// ADR-0023 §8 / ADR-0025 §7 / ADR-0026 / ADR-0027 §13: current counts
  /// from all8 domains via SQL COUNT(*). Used for destructive-action
  /// preview (replace/delete-all dialogs).
  Future<CurrentCounts> getCurrentCounts() async {
    final txCount = await _transactionDataSource.count();
    final bCount = await _budgetDataSource.count();
    final rCount = await _recurringDataSource.count();
    final qtCount = await _quickTemplateDataSource.count();
    final bsCount = await _budgetSnapshotDataSource.count();
    final bpCount = await _budgetPlanDataSource.count();
    final bpiCount = await _budgetPlanDataSource.itemCount();
    final catCount = await _categoryDataSource.count();
    return CurrentCounts(
      transactionCount: txCount,
      budgetCount: bCount,
      recurringCount: rCount,
      quickTemplateCount: qtCount,
      budgetSnapshotCount: bsCount,
      budgetPlanCount: bpCount,
      budgetPlanItemCount: bpiCount,
      categoryCount: catCount,
    );
  }

  /// ADR-0023 §7 / ADR-0025 §7 / ADR-0026 / ADR-0027 §13: delete-all
  /// semantics — clears all user data atomically. DB tables cleared in one
  /// transaction; totalBudget reset after the transaction succeeds. If
  /// totalBudget reset fails, throws [ClearDataPartialFailure] so the caller
  /// can surface the error. No undo for this operation.
  ///
  /// Budget plan tables are deleted directly here (not via
  /// [BudgetPlanLocalDataSource.clearAll]) because the latter wraps its own
  /// `runInTransaction` which would conflict with the outer transaction.
  Future<void> clearAllUserData() async {
    await _dbHelper.runInTransaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('recurring_transactions');
      await txn.delete('quick_templates');
      await txn.delete('budget_snapshots'); // ADR-0025
      await txn.delete('budget_plan_items'); // ADR-0026
      await txn.delete('budget_plans'); // ADR-0026
      await txn.delete('categories'); // ADR-0027
    });
    // Reset totalBudget only after DB transaction succeeds.
    // Failure here means DB is cleared but totalBudget may still be non-zero.
    try {
      await _storageService.saveValue('total_budget', 0);
    } catch (e) {
      throw ClearDataPartialFailure(
        'Xoá dữ liệu hoàn tất nhưng không reset được tổng ngân sách. '
        'Vui lòng kiểm tra cài đặt ứng dụng.',
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
        categoryId: seedCategories[catIndex].id,
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
        categoryId: 'food_out',
        monthlyLimit: 3000000,
        alertThreshold: 80,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      Budget(
        id: uuid.v4(),
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      Budget(
        id: uuid.v4(),
        categoryName: 'Mua online',
        categoryId: 'online_shopping',
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
        categoryId: 'subscription',
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
        categoryId: 'housing',
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
        categoryId: 'food_out',
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
        categoryId: 'coffee',
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
        categoryId: 'online_shopping',
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
      budgetSnapshots: [],
      budgetPlans: const [],
      budgetPlanItems: const [],
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

  Map<String, dynamic> _budgetSnapshotToMap(BudgetSnapshot s) =>
      budgetSnapshotToRow(s);

  Map<String, dynamic> _budgetPlanToMap(BudgetPlan p) =>
      budgetPlanToRow(p);

  Map<String, dynamic> _budgetPlanItemToMap(BudgetPlanItem i) =>
      budgetPlanItemToRow(i);

  Map<String, dynamic> _categoryToMap(Category c) => categoryToRow(c);
}

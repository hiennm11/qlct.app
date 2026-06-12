import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../database/database_helper.dart';
import '../mappers/transaction_row_mapper.dart';
import '../../models/transaction.dart';
import '../../core/constants.dart';
import '../../core/vietnamese_text_normalizer.dart';

class MigrationService {
  static const _migrationFlag = 'migrated_to_sqlite_v1';

  final DatabaseHelper _dbHelper;

  MigrationService(this._dbHelper);

  Future<void> migrate() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_migrationFlag)) return;

    final jsonString = prefs.getString(AppConstants.transactionsKey);
    if (jsonString == null || jsonString.isEmpty) {
      await prefs.setBool(_migrationFlag, true);
      return;
    }

    final transactions = _parseOldTransactions(jsonString);
    if (transactions.isEmpty) {
      // All rows corrupt — nothing to migrate, set flag to prevent retry loop
      debugPrint(
          '⚠️ Migration: no valid transactions parsed, setting flag');
      await prefs.setBool(_migrationFlag, true);
      return;
    }

    try {
      await _dbHelper.runInTransaction((txn) async {
        for (final t in transactions) {
          await txn.insert(
            'transactions',
            transactionToRow(t),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

      // Backup old data before clearing
      await prefs.setString(
          '${AppConstants.transactionsKey}_backup_v1', jsonString);

      // Only set flag AFTER successful transaction commit
      await prefs.setBool(_migrationFlag, true);
      await prefs.remove(AppConstants.transactionsKey);

      debugPrint(
          '✅ Migrated ${transactions.length} transactions from SharedPreferences to SQLite');
    } catch (e, stack) {
      debugPrint('❌ Migration failed: $e');
      debugPrint('📍 Stack: $stack');
      // Do NOT set flag — retry on next launch
      rethrow;
    }
  }

  /// Parse old JSON format with per-row error handling.
  /// Skips corrupt rows instead of failing the entire migration.
  List<Transaction> _parseOldTransactions(String jsonString) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final result = <Transaction>[];
      int skipped = 0;

      for (int i = 0; i < decoded.length; i++) {
        try {
          final map = decoded[i] as Map<String, dynamic>;
          final categoryName = map['category'] as String;
          result.add(Transaction(
            id: map['id'].toString(),
            amount: (map['amount'] as num).toInt(),
            category: categoryName,
            categoryId: 'migrated_${normalizeVietnameseSearchText(categoryName)}',
            emoji: (map['emoji'] ?? '') as String,
            date: DateTime.parse(map['date'] as String),
            note: (map['note'] ?? '') as String,
          ));
        } catch (e) {
          skipped++;
          debugPrint('⚠️ Migration: skipping corrupt row #$i: $e');
        }
      }

      if (skipped > 0) {
        debugPrint(
            '⚠️ Migration: skipped $skipped corrupt rows out of ${decoded.length}');
      }
      return result;
    } on FormatException catch (e) {
      debugPrint('❌ Migration: invalid JSON — $e');
      return [];
    }
  }
}

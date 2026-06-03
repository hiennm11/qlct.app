import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../datasources/transaction_local_datasource.dart';
import '../../models/transaction.dart';
import '../../core/constants.dart';

class MigrationService {
  static const _migrationFlag = 'migrated_to_sqlite_v1';

  final TransactionLocalDataSource _dataSource;

  MigrationService(this._dataSource);

  Future<void> migrate() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_migrationFlag)) return;

    final jsonString = prefs.getString(AppConstants.transactionsKey);
    if (jsonString == null || jsonString.isEmpty) {
      await prefs.setBool(_migrationFlag, true);
      return;
    }

    try {
      final transactions = _parseOldTransactions(jsonString);

      for (final t in transactions) {
        await _dataSource.add(t);
      }

      await prefs.setBool(_migrationFlag, true);
      await prefs.remove(AppConstants.transactionsKey);

      debugPrint('✅ Migrated ${transactions.length} transactions from SharedPreferences to SQLite');
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
    }
  }

  /// Parse old JSON format. Old format: jsonEncode of List of Map String,dynamic
  /// where each map has string keys matching old Transaction fields (id: int, etc.)
  /// Old ID was int, new ID is String — convert toString()
  List<Transaction> _parseOldTransactions(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return Transaction(
        id: map['id'].toString(),
        amount: (map['amount'] as num).toInt(),
        category: map['category'] as String,
        emoji: (map['emoji'] ?? '') as String,
        date: DateTime.parse(map['date'] as String),
        note: (map['note'] ?? '') as String,
      );
    }).toList();
  }
}
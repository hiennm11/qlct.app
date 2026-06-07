import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/quick_template.dart';

part 'backup_data.freezed.dart';
part 'backup_data.g.dart';

/// Current backup schema version.
/// v1: initial release (transactions + budgets + recurrings + totalBudget).
/// v2: adds quickTemplates (ADR-0019).
const int currentSchemaVersion = 2;

/// Full backup payload containing all app data
@freezed
class BackupData with _$BackupData {
  const factory BackupData({
    required int schemaVersion,
    required String exportedAt,
    required String appVersion,
    @Default(0) int totalBudget,
    @Default([]) List<Transaction> transactions,
    @Default([]) List<Budget> budgets,
    @Default([]) List<RecurringTransaction> recurringTransactions,
    @Default([]) List<QuickTemplate> quickTemplates,
  }) = _BackupData;

  factory BackupData.fromJson(Map<String, dynamic> json) =>
      _$BackupDataFromJson(json);
}

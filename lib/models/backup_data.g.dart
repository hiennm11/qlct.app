// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BackupDataImpl _$$BackupDataImplFromJson(Map<String, dynamic> json) =>
    _$BackupDataImpl(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      exportedAt: json['exportedAt'] as String,
      appVersion: json['appVersion'] as String,
      totalBudget: (json['totalBudget'] as num?)?.toInt() ?? 0,
      transactions:
          (json['transactions'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      budgets:
          (json['budgets'] as List<dynamic>?)
              ?.map((e) => Budget.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recurringTransactions:
          (json['recurringTransactions'] as List<dynamic>?)
              ?.map(
                (e) => RecurringTransaction.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      quickTemplates:
          (json['quickTemplates'] as List<dynamic>?)
              ?.map((e) => QuickTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$BackupDataImplToJson(_$BackupDataImpl instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'exportedAt': instance.exportedAt,
      'appVersion': instance.appVersion,
      'totalBudget': instance.totalBudget,
      'transactions': instance.transactions,
      'budgets': instance.budgets,
      'recurringTransactions': instance.recurringTransactions,
      'quickTemplates': instance.quickTemplates,
    };

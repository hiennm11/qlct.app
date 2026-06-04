// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecurringTransactionImpl _$$RecurringTransactionImplFromJson(
  Map<String, dynamic> json,
) => _$RecurringTransactionImpl(
  id: json['id'] as String,
  categoryName: json['categoryName'] as String,
  amount: (json['amount'] as num).toInt(),
  note: json['note'] as String? ?? '',
  frequency: json['frequency'] as String? ?? 'daily',
  nextRunAt: DateTime.parse(json['nextRunAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$RecurringTransactionImplToJson(
  _$RecurringTransactionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'categoryName': instance.categoryName,
  'amount': instance.amount,
  'note': instance.note,
  'frequency': instance.frequency,
  'nextRunAt': instance.nextRunAt.toIso8601String(),
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
};

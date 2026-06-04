// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: json['id'] as String,
      amount: (json['amount'] as num).toInt(),
      category: json['category'] as String,
      emoji: json['emoji'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String? ?? '',
      sourceRecurringId: json['sourceRecurringId'] as String? ?? null,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'category': instance.category,
      'emoji': instance.emoji,
      'date': instance.date.toIso8601String(),
      'note': instance.note,
      'sourceRecurringId': instance.sourceRecurringId,
    };

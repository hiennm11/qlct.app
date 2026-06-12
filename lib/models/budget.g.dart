// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BudgetImpl _$$BudgetImplFromJson(Map<String, dynamic> json) => _$BudgetImpl(
  id: json['id'] as String,
  categoryName: json['categoryName'] as String,
  categoryId: json['categoryId'] as String,
  monthlyLimit: (json['monthlyLimit'] as num).toInt(),
  alertThreshold: (json['alertThreshold'] as num?)?.toInt() ?? 80,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$BudgetImplToJson(_$BudgetImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'categoryName': instance.categoryName,
      'categoryId': instance.categoryId,
      'monthlyLimit': instance.monthlyLimit,
      'alertThreshold': instance.alertThreshold,
      'createdAt': instance.createdAt.toIso8601String(),
    };

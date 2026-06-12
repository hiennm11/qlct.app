// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BudgetSnapshotImpl _$$BudgetSnapshotImplFromJson(Map<String, dynamic> json) =>
    _$BudgetSnapshotImpl(
      yearMonth: json['yearMonth'] as String,
      categoryName: json['categoryName'] as String,
      categoryId: json['categoryId'] as String,
      limitAmount: (json['limitAmount'] as num).toInt(),
      alertThreshold: (json['alertThreshold'] as num?)?.toInt() ?? 80,
      createdAt: DateTime.parse(json['createdAt'] as String),
      carryAmount: (json['carryAmount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$BudgetSnapshotImplToJson(
  _$BudgetSnapshotImpl instance,
) => <String, dynamic>{
  'yearMonth': instance.yearMonth,
  'categoryName': instance.categoryName,
  'categoryId': instance.categoryId,
  'limitAmount': instance.limitAmount,
  'alertThreshold': instance.alertThreshold,
  'createdAt': instance.createdAt.toIso8601String(),
  'carryAmount': instance.carryAmount,
};

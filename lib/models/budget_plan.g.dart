// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BudgetPlanImpl _$$BudgetPlanImplFromJson(Map<String, dynamic> json) =>
    _$BudgetPlanImpl(
      yearMonth: json['yearMonth'] as String,
      plannedTotalBudget: (json['plannedTotalBudget'] as num).toInt(),
      source: json['source'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      appliedAt: json['appliedAt'] == null
          ? null
          : DateTime.parse(json['appliedAt'] as String),
    );

Map<String, dynamic> _$$BudgetPlanImplToJson(_$BudgetPlanImpl instance) =>
    <String, dynamic>{
      'yearMonth': instance.yearMonth,
      'plannedTotalBudget': instance.plannedTotalBudget,
      'source': instance.source,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'appliedAt': instance.appliedAt?.toIso8601String(),
    };

_$BudgetPlanItemImpl _$$BudgetPlanItemImplFromJson(Map<String, dynamic> json) =>
    _$BudgetPlanItemImpl(
      yearMonth: json['yearMonth'] as String,
      categoryName: json['categoryName'] as String,
      plannedLimit: (json['plannedLimit'] as num).toInt(),
      alertThreshold: (json['alertThreshold'] as num?)?.toInt() ?? 80,
      suggestedLimit: (json['suggestedLimit'] as num?)?.toInt() ?? 0,
      baseLimit: (json['baseLimit'] as num?)?.toInt() ?? 0,
      lastMonthSpent: (json['lastMonthSpent'] as num?)?.toInt() ?? 0,
      wasOverBudgetLastMonth: json['wasOverBudgetLastMonth'] as bool? ?? false,
      recommendation: json['recommendation'] as String? ?? 'keep',
    );

Map<String, dynamic> _$$BudgetPlanItemImplToJson(
  _$BudgetPlanItemImpl instance,
) => <String, dynamic>{
  'yearMonth': instance.yearMonth,
  'categoryName': instance.categoryName,
  'plannedLimit': instance.plannedLimit,
  'alertThreshold': instance.alertThreshold,
  'suggestedLimit': instance.suggestedLimit,
  'baseLimit': instance.baseLimit,
  'lastMonthSpent': instance.lastMonthSpent,
  'wasOverBudgetLastMonth': instance.wasOverBudgetLastMonth,
  'recommendation': instance.recommendation,
};

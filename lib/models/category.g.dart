// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryImpl _$$CategoryImplFromJson(Map<String, dynamic> json) =>
    _$CategoryImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      normalizedName: json['normalizedName'] as String,
      emoji: json['emoji'] as String,
      kind: $enumDecode(_$CategoryKindEnumMap, json['kind']),
      budgetBehavior: $enumDecode(
        _$BudgetBehaviorEnumMap,
        json['budgetBehavior'],
      ),
      quickAmountMin: (json['quickAmountMin'] as num).toInt(),
      quickAmountDefault: (json['quickAmountDefault'] as num).toInt(),
      quickAmountMax: (json['quickAmountMax'] as num).toInt(),
      voicePhrases: (json['voicePhrases'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      sortOrder: (json['sortOrder'] as num).toInt(),
      isSystem: json['isSystem'] as bool? ?? true,
      isArchived: json['isArchived'] as bool? ?? false,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$CategoryImplToJson(_$CategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'normalizedName': instance.normalizedName,
      'emoji': instance.emoji,
      'kind': _$CategoryKindEnumMap[instance.kind]!,
      'budgetBehavior': _$BudgetBehaviorEnumMap[instance.budgetBehavior]!,
      'quickAmountMin': instance.quickAmountMin,
      'quickAmountDefault': instance.quickAmountDefault,
      'quickAmountMax': instance.quickAmountMax,
      'voicePhrases': instance.voicePhrases,
      'sortOrder': instance.sortOrder,
      'isSystem': instance.isSystem,
      'isArchived': instance.isArchived,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$CategoryKindEnumMap = {
  CategoryKind.spending: 'spending',
  CategoryKind.investment: 'investment',
};

const _$BudgetBehaviorEnumMap = {
  BudgetBehavior.flexible: 'flexible',
  BudgetBehavior.fixed: 'fixed',
  BudgetBehavior.excluded: 'excluded',
};

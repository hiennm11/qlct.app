// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QuickTemplateImpl _$$QuickTemplateImplFromJson(Map<String, dynamic> json) =>
    _$QuickTemplateImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toInt(),
      categoryName: json['categoryName'] as String,
      note: json['note'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$QuickTemplateImplToJson(_$QuickTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'amount': instance.amount,
      'categoryName': instance.categoryName,
      'note': instance.note,
      'emoji': instance.emoji,
      'isPinned': instance.isPinned,
      'usageCount': instance.usageCount,
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

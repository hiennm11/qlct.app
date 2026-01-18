// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryImpl _$$CategoryImplFromJson(Map<String, dynamic> json) =>
    _$CategoryImpl(
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      minAmount: (json['minAmount'] as num).toInt(),
      defaultAmount: (json['defaultAmount'] as num).toInt(),
      maxAmount: (json['maxAmount'] as num).toInt(),
      phrases: (json['phrases'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      isInvestment: json['isInvestment'] as bool? ?? false,
    );

Map<String, dynamic> _$$CategoryImplToJson(_$CategoryImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'emoji': instance.emoji,
      'minAmount': instance.minAmount,
      'defaultAmount': instance.defaultAmount,
      'maxAmount': instance.maxAmount,
      'phrases': instance.phrases,
      'isInvestment': instance.isInvestment,
    };

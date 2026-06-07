import 'package:freezed_annotation/freezed_annotation.dart';

part 'quick_template.freezed.dart';
part 'quick_template.g.dart';

/// Immutable quick template model — preset transaction shortcut.
@freezed
class QuickTemplate with _$QuickTemplate {
  const factory QuickTemplate({
    required String id,
    required String title,
    required int amount,
    required String categoryName,
    @Default('') String note,
    @Default('') String emoji,
    @Default(false) bool isPinned,
    @Default(0) int usageCount,
    @Default(null) DateTime? lastUsedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _QuickTemplate;

  factory QuickTemplate.fromJson(Map<String, dynamic> json) =>
      _$QuickTemplateFromJson(json);
}
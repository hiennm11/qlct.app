import 'package:freezed_annotation/freezed_annotation.dart';

part 'merge_preview.freezed.dart';

/// ADR-0038: dry-run preview of rows that would be affected by a category
/// merge. Per-table counts for the 6 financial tables that hold
/// `category_id` references.
@freezed
class MergePreview with _$MergePreview {
  const factory MergePreview({
    @Default(0) int transactions,
    @Default(0) int budgets,
    @Default(0) int snapshots,
    @Default(0) int planItems,
    @Default(0) int recurring,
    @Default(0) int quickTemplates,
  }) = _MergePreview;
}

/// ADR-0038: result of a successful category merge. Echoes the affected
/// counts so the UI can confirm what was moved.
@freezed
class MergeResult with _$MergeResult {
  const factory MergeResult({
    required MergePreview affected,
    required String sourceId,
    required String targetId,
  }) = _MergeResult;
}

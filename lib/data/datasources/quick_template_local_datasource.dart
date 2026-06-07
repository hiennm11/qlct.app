import '../../models/quick_template.dart';

/// Persistence seam for QuickTemplate domain.
abstract class QuickTemplateLocalDataSource {
  /// All templates ordered for management display.
  Future<List<QuickTemplate>> getAll();

  /// Top [limit] templates for strip: pinned first, then usageCount DESC,
  /// lastUsedAt DESC, createdAt DESC. Default limit 8.
  Future<List<QuickTemplate>> getTopTemplates({int limit = 8});

  Future<QuickTemplate?> getById(String id);

  /// Check if an exact duplicate exists (title, amount, categoryName, note).
  /// Pass [excludeId] to skip the matching row during updates.
  Future<bool> existsExactDuplicate({
    required String title,
    required int amount,
    required String categoryName,
    required String note,
    String? excludeId,
  });

  Future<void> insert(QuickTemplate template);
  Future<void> update(QuickTemplate template);
  Future<void> delete(String id);

  /// Increment usageCount and set lastUsedAt to now.
  Future<void> markUsed(String id, DateTime usedAt);

  /// Bulk insert for restore.
  Future<void> insertMany(List<QuickTemplate> templates);

  /// Delete all templates (used in replace restore).
  Future<void> clearAll();
}
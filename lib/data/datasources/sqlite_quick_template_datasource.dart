import 'package:sqflite/sqflite.dart';
import '../../models/quick_template.dart';
import '../database/database_helper.dart';
import '../mappers/quick_template_mapper.dart';
import 'quick_template_local_datasource.dart';

class SqliteQuickTemplateDataSource implements QuickTemplateLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteQuickTemplateDataSource(this._dbHelper);

  @override
  Future<List<QuickTemplate>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'quick_templates',
      orderBy: 'is_pinned DESC, usage_count DESC, '
          'CASE WHEN last_used_at IS NULL THEN 1 ELSE 0 END, '
          'last_used_at DESC, created_at DESC',
    );
    return maps.map(quickTemplateFromRow).toList();
  }

  @override
  Future<List<QuickTemplate>> getTopTemplates({int limit = 8}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'quick_templates',
      orderBy: 'is_pinned DESC, usage_count DESC, '
          'CASE WHEN last_used_at IS NULL THEN 1 ELSE 0 END, '
          'last_used_at DESC, created_at DESC',
      limit: limit,
    );
    return maps.map(quickTemplateFromRow).toList();
  }

  @override
  Future<QuickTemplate?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'quick_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return quickTemplateFromRow(maps.first);
  }

  @override
  Future<bool> existsExactDuplicate({
    required String title,
    required int amount,
    required String categoryName,
    required String note,
    String? excludeId,
  }) async {
    final db = await _dbHelper.database;
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedNote = note.trim().toLowerCase();

    final where = excludeId == null
        ? 'LOWER(TRIM(title)) = ? AND amount = ? AND category_name = ? AND LOWER(TRIM(note)) = ?'
        : 'LOWER(TRIM(title)) = ? AND amount = ? AND category_name = ? AND LOWER(TRIM(note)) = ? AND id != ?';
    final whereArgs = excludeId == null
        ? [normalizedTitle, amount, categoryName, normalizedNote]
        : [normalizedTitle, amount, categoryName, normalizedNote, excludeId];

    final result = await db.query(
      'quick_templates',
      columns: ['id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> insert(QuickTemplate template) async {
    final db = await _dbHelper.database;
    await db.insert(
      'quick_templates',
      quickTemplateToRow(template),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(QuickTemplate template) async {
    final db = await _dbHelper.database;
    await db.update(
      'quick_templates',
      quickTemplateToRow(template),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'quick_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markUsed(String id, DateTime usedAt) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE quick_templates SET usage_count = usage_count + 1, '
      'last_used_at = ? WHERE id = ?',
      [usedAt.toIso8601String(), id],
    );
  }

  @override
  Future<void> insertMany(List<QuickTemplate> templates) async {
    if (templates.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final t in templates) {
      batch.insert('quick_templates', quickTemplateToRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('quick_templates');
  }
}
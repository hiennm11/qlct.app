import 'package:sqflite/sqflite.dart';
import 'package:qlct/core/vietnamese_text_normalizer.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/merge_preview.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/mappers/category_row_mapper.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';

/// Max allowed quick_amount_max per ADR-0027 §14 validation.
const int _kMaxQuickAmount = 999999999;

class SqliteCategoryDataSource implements CategoryLocalDataSource {
  final DatabaseHelper _dbHelper;
  SqliteCategoryDataSource(this._dbHelper);

  /// Validates ADR-0027 §14 rules. Throws [CategoryValidationException] on fail.
  static void validate(Category c) {
    if (c.name.trim().isEmpty) {
      throw CategoryValidationException('name must not be empty');
    }
    if (c.emoji.trim().isEmpty) {
      throw CategoryValidationException('emoji must not be empty');
    }
    if (c.quickAmountMin <= 0) {
      throw CategoryValidationException('quickAmountMin must be > 0');
    }
    if (c.quickAmountMin > c.quickAmountDefault) {
      throw CategoryValidationException(
        'quickAmountMin (${c.quickAmountMin}) must be <= quickAmountDefault (${c.quickAmountDefault})',
      );
    }
    if (c.quickAmountDefault > c.quickAmountMax) {
      throw CategoryValidationException(
        'quickAmountDefault (${c.quickAmountDefault}) must be <= quickAmountMax (${c.quickAmountMax})',
      );
    }
    if (c.quickAmountMax > _kMaxQuickAmount) {
      throw CategoryValidationException(
        'quickAmountMax (${c.quickAmountMax}) must be <= $_kMaxQuickAmount',
      );
    }
    if (c.voicePhrases.any((p) => p.trim().isEmpty)) {
      throw CategoryValidationException(
        'voicePhrases must not contain empty values after trim',
      );
    }
    // Normalized name must be in sync with the name.
    final expected = normalizeVietnameseSearchText(c.name);
    if (c.normalizedName != expected) {
      throw CategoryValidationException(
        'normalizedName (${c.normalizedName}) must equal '
        'normalizeVietnameseSearchText(name) ($expected)',
      );
    }
  }

  @override
  Future<List<Category>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      // ADR-0037: filter out soft-deleted. Trash reads use getDeleted.
      where: 'deleted_at IS NULL',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map(categoryFromRow).toList();
  }

  @override
  Future<List<Category>> getActive() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'is_archived = 0 AND deleted_at IS NULL',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map(categoryFromRow).toList();
  }

  @override
  Future<List<Category>> getDeleted() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return maps.map(categoryFromRow).toList();
  }

  @override
  Future<Category?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return categoryFromRow(maps.first);
  }

  @override
  Future<Category?> getByName(String name) async {
    if (name.trim().isEmpty) return null;
    final normalized = normalizeVietnameseSearchText(name);
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'normalized_name = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return categoryFromRow(maps.first);
  }

  @override
  Future<void> upsert(Category category) async {
    validate(category);
    final db = await _dbHelper.database;
    await db.insert(
      'categories',
      categoryToRow(category),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> bulkUpsert(List<Category> categories) async {
    if (categories.isEmpty) return;
    for (final c in categories) {
      validate(c);
    }
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final c in categories) {
      batch.insert(
        'categories',
        categoryToRow(c),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM categories');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> seedDefaultsIfEmpty() async {
    final existing = await count();
    if (existing > 0) return;
    final defaults = seedCategories;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final c in defaults) {
      batch.insert(
        'categories',
        categoryToRow(c),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> softDelete(String id, {DateTime? deletedAt}) async {
    final db = await _dbHelper.database;
    final ts = (deletedAt ?? DateTime.now()).millisecondsSinceEpoch;
    await db.update(
      'categories',
      {
        'deleted_at': ts,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND id != ? AND is_system = 0',
      whereArgs: [id, 'other'],
    );
  }

  @override
  Future<void> restore(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      {
        'deleted_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> touchUpdatedAt(String id, DateTime updatedAt) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      {'updated_at': updatedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateSortOrder(
    String id,
    int sortOrder,
    DateTime updatedAt,
  ) async {
    final db = await _dbHelper.database;
    // Targeted write — does NOT call validate() on the row's other fields.
    // Reorder is purely a sortOrder mutation; we must not block it on
    // stale normalizedName or any other field invariant. No-op if id
    // does not exist (db.update with no matches returns 0 rows).
    await db.update(
      'categories',
      {
        'sort_order': sortOrder,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== ADR-0038: Merge categories =====

  /// Guard helper: throws [CategoryMergeCollision] when source/target
  /// are the same id, or when source is the protected `other` fallback.
  void _checkMergeable(String sourceId, String targetId) {
    if (sourceId == targetId) {
      throw CategoryMergeCollision('sameCategory',
          'Danh mục nguồn và đích phải khác nhau');
    }
    if (sourceId == 'other') {
      throw CategoryMergeCollision('protectedSource',
          'Không thể hợp nhất danh mục "Khác"');
    }
  }

  @override
  Future<MergePreview> getMergePreview(
    String sourceId,
    String targetId,
  ) async {
    _checkMergeable(sourceId, targetId);
    final db = await _dbHelper.database;
    Future<int> count(String table) async {
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table WHERE category_id = ?',
        [sourceId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }

    return MergePreview(
      transactions: await count('transactions'),
      budgets: await count('budgets'),
      snapshots: await count('budget_snapshots'),
      planItems: await count('budget_plan_items'),
      recurring: await count('recurring_transactions'),
      quickTemplates: await count('quick_templates'),
    );
  }

  @override
  Future<MergeResult> merge(String sourceId, String targetId) async {
    _checkMergeable(sourceId, targetId);
    final preview = await getMergePreview(sourceId, targetId);
    await _dbHelper.runInTransaction((txn) async {
      // 1. transactions (no UNIQUE on category_id)
      await txn.update('transactions', {'category_id': targetId},
          where: 'category_id = ?', whereArgs: [sourceId]);
      // 2. budgets — UNIQUE(category_id) blocks
      final targetBudget = await txn.query('budgets',
          where: 'category_id = ?', whereArgs: [targetId], limit: 1);
      if (targetBudget.isNotEmpty) {
        throw CategoryMergeCollision('budgetExists',
            'Danh mục đích đã có ngân sách — xoá ngân sách đích trước');
      }
      await txn.update('budgets', {'category_id': targetId},
          where: 'category_id = ?', whereArgs: [sourceId]);
      // 3. budget_snapshots — composite PK (year_month, category_id).
      // On PK collision with target, drop source's row (LIMIT 1 win to target).
      final sourceSnaps = await txn.query('budget_snapshots',
          columns: ['year_month'],
          where: 'category_id = ?', whereArgs: [sourceId]);
      for (final snap in sourceSnaps) {
        final ym = snap['year_month'] as String;
        try {
          await txn.update('budget_snapshots', {'category_id': targetId},
              where: 'category_id = ? AND year_month = ?',
              whereArgs: [sourceId, ym]);
        } on DatabaseException {
          // PK collision: target already has (ym, targetId) — drop source's
          await txn.delete('budget_snapshots',
              where: 'category_id = ? AND year_month = ?',
              whereArgs: [sourceId, ym]);
        }
      }
      // 4. budget_plan_items — same PK collision handling
      final sourcePlans = await txn.query('budget_plan_items',
          columns: ['year_month'],
          where: 'category_id = ?', whereArgs: [sourceId]);
      for (final plan in sourcePlans) {
        final ym = plan['year_month'] as String;
        try {
          await txn.update('budget_plan_items', {'category_id': targetId},
              where: 'category_id = ? AND year_month = ?',
              whereArgs: [sourceId, ym]);
        } on DatabaseException {
          await txn.delete('budget_plan_items',
              where: 'category_id = ? AND year_month = ?',
              whereArgs: [sourceId, ym]);
        }
      }
      // 5. recurring (no UNIQUE)
      await txn.update('recurring_transactions', {'category_id': targetId},
          where: 'category_id = ?', whereArgs: [sourceId]);
      // 6. quick_templates (no UNIQUE)
      await txn.update('quick_templates', {'category_id': targetId},
          where: 'category_id = ?', whereArgs: [sourceId]);
      // 7. soft-delete source (reuses existing softDelete WHERE guard)
      final now = DateTime.now();
      await txn.update('categories', {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
          where: 'id = ? AND id != ? AND is_system = 0',
          whereArgs: [sourceId, 'other']);
    });
    return MergeResult(
      affected: preview,
      sourceId: sourceId,
      targetId: targetId,
    );
  }
}

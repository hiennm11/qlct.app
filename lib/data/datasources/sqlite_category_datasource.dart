import 'package:sqflite/sqflite.dart';
import 'package:qlct/core/vietnamese_text_normalizer.dart';
import 'package:qlct/models/category.dart';
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
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map(categoryFromRow).toList();
  }

  @override
  Future<List<Category>> getActive() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'is_archived = 0',
      orderBy: 'sort_order ASC, name ASC',
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
}

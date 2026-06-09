import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../mappers/budget_plan_row_mapper.dart';
import '../../models/budget_plan.dart';
import 'budget_plan_local_datasource.dart';

/// SQLite implementation of [BudgetPlanLocalDataSource].
class SqliteBudgetPlanDataSource implements BudgetPlanLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteBudgetPlanDataSource(this._dbHelper);

  @override
  Future<BudgetPlan?> getPlan(String yearMonth) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budget_plans',
      where: 'year_month = ?',
      whereArgs: [yearMonth],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return budgetPlanFromRow(maps.first);
  }

  @override
  Future<List<BudgetPlanItem>> getItems(String yearMonth) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budget_plan_items',
      where: 'year_month = ?',
      whereArgs: [yearMonth],
      orderBy: 'category_name ASC',
    );
    return maps.map(budgetPlanItemFromRow).toList();
  }

  @override
  Future<BudgetPlan?> getDraft(String yearMonth) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budget_plans',
      where: 'year_month = ? AND status = ?',
      whereArgs: [yearMonth, 'draft'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return budgetPlanFromRow(maps.first);
  }

  @override
  Future<void> upsertPlan(BudgetPlan plan) async {
    final db = await _dbHelper.database;
    final existing = await db.query(
      'budget_plans',
      columns: ['year_month'],
      where: 'year_month = ?',
      whereArgs: [plan.yearMonth],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      // Update non-PK fields only — avoids FK cascade from REPLACE
      await db.update(
        'budget_plans',
        {
          'planned_total_budget': plan.plannedTotalBudget,
          'source': plan.source,
          'status': plan.status,
          'updated_at': plan.updatedAt.millisecondsSinceEpoch,
          'applied_at': plan.appliedAt?.millisecondsSinceEpoch,
        },
        where: 'year_month = ?',
        whereArgs: [plan.yearMonth],
      );
    } else {
      await db.insert('budget_plans', budgetPlanToRow(plan));
    }
  }

  @override
  Future<void> bulkUpsertItems(List<BudgetPlanItem> items) async {
    if (items.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'budget_plan_items',
        budgetPlanItemToRow(item),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> saveDraft(BudgetPlan plan, List<BudgetPlanItem> items) async {
    await _dbHelper.runInTransaction((txn) async {
      // Upsert plan header — update-or-insert to avoid FK cascade
      final existing = await txn.query(
        'budget_plans',
        columns: ['year_month'],
        where: 'year_month = ?',
        whereArgs: [plan.yearMonth],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.update(
          'budget_plans',
          {
            'planned_total_budget': plan.plannedTotalBudget,
            'source': plan.source,
            'status': plan.status,
            'updated_at': plan.updatedAt.millisecondsSinceEpoch,
            'applied_at': plan.appliedAt?.millisecondsSinceEpoch,
          },
          where: 'year_month = ?',
          whereArgs: [plan.yearMonth],
        );
      } else {
        await txn.insert('budget_plans', budgetPlanToRow(plan));
      }
      // Delete existing items for this yearMonth
      await txn.delete(
        'budget_plan_items',
        where: 'year_month = ?',
        whereArgs: [plan.yearMonth],
      );
      // Insert new items
      for (final item in items) {
        await txn.insert(
          'budget_plan_items',
          budgetPlanItemToRow(item),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> markApplied(String yearMonth, DateTime appliedAt) async {
    final db = await _dbHelper.database;
    await db.update(
      'budget_plans',
      {
        'status': 'applied',
        'applied_at': appliedAt.millisecondsSinceEpoch,
        'updated_at': appliedAt.millisecondsSinceEpoch,
      },
      where: 'year_month = ?',
      whereArgs: [yearMonth],
    );
  }

  @override
  Future<void> delete(String yearMonth) async {
    await _dbHelper.runInTransaction((txn) async {
      // Delete items first (explicit over FK reliance)
      await txn.delete(
        'budget_plan_items',
        where: 'year_month = ?',
        whereArgs: [yearMonth],
      );
      // Delete plan header
      await txn.delete(
        'budget_plans',
        where: 'year_month = ?',
        whereArgs: [yearMonth],
      );
    });
  }

  @override
  Future<void> clearAll() async {
    await _dbHelper.runInTransaction((txn) async {
      await txn.delete('budget_plan_items');
      await txn.delete('budget_plans');
    });
  }

  @override
  Future<List<BudgetPlan>> getAllPlans() async {
    final db = await _dbHelper.database;
    final maps = await db.query('budget_plans');
    return maps.map(budgetPlanFromRow).toList();
  }

  @override
  Future<List<BudgetPlanItem>> getAllItems() async {
    final db = await _dbHelper.database;
    final maps = await db.query('budget_plan_items');
    return maps.map(budgetPlanItemFromRow).toList();
  }

  @override
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM budget_plans');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> itemCount() async {
    final db = await _dbHelper.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM budget_plan_items');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

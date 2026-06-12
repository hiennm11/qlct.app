import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:qlct/core/vietnamese_text_normalizer.dart';

class DatabaseHelper {
  static const _databaseName = 'qlct.db';
  static const _databaseVersion = 13;

  Database? _database;
  String? _testPathOverride;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = _testPathOverride ?? join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id                       TEXT PRIMARY KEY,
        amount                   INTEGER NOT NULL,
        category                 TEXT NOT NULL,
        category_id              TEXT NOT NULL,
        emoji                    TEXT NOT NULL DEFAULT '',
        date                     TEXT NOT NULL,
        note                     TEXT NOT NULL DEFAULT '',
        source_recurring_id      TEXT,
        created_at               INTEGER NOT NULL,
        search_text_normalized   TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_transactions_category_id ON transactions(category_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
    await db.execute('''
      CREATE TABLE budgets (
        id              TEXT PRIMARY KEY,
        category_name   TEXT NOT NULL,
        category_id     TEXT NOT NULL,
        monthly_limit   INTEGER NOT NULL,
        alert_threshold INTEGER NOT NULL DEFAULT 80,
        created_at      INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_id)');
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id            TEXT PRIMARY KEY,
        category_name TEXT NOT NULL,
        category_id   TEXT NOT NULL,
        amount        INTEGER NOT NULL,
        note          TEXT NOT NULL DEFAULT '',
        frequency     TEXT NOT NULL,
        next_run_at   TEXT NOT NULL,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at)');
    await db.execute('CREATE INDEX idx_recurring_category_id ON recurring_transactions(category_id)');
    await db.execute('''
      CREATE TABLE quick_templates (
        id              TEXT PRIMARY KEY,
        title           TEXT NOT NULL,
        amount          INTEGER NOT NULL,
        category_name   TEXT NOT NULL,
        category_id     TEXT NOT NULL,
        note            TEXT NOT NULL DEFAULT '',
        emoji           TEXT NOT NULL,
        is_pinned       INTEGER NOT NULL DEFAULT 0,
        usage_count     INTEGER NOT NULL DEFAULT 0,
        last_used_at    TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quick_templates_pinned ON quick_templates(is_pinned)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quick_templates_usage ON quick_templates(usage_count DESC, last_used_at DESC)');
    await db.execute('''
      CREATE TABLE budget_snapshots (
        year_month      TEXT NOT NULL,
        category_name   TEXT NOT NULL,
        category_id     TEXT NOT NULL,
        limit_amount    INTEGER NOT NULL,
        alert_threshold INTEGER NOT NULL DEFAULT 80,
        created_at      INTEGER NOT NULL,
        PRIMARY KEY (year_month, category_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_plans (
        year_month            TEXT NOT NULL PRIMARY KEY,
        planned_total_budget  INTEGER NOT NULL DEFAULT 0,
        source                TEXT NOT NULL,
        status                TEXT NOT NULL DEFAULT 'draft',
        created_at            INTEGER NOT NULL,
        updated_at            INTEGER NOT NULL,
        applied_at            INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_plan_items (
        year_month                   TEXT NOT NULL,
        category_name                TEXT NOT NULL,
        category_id                  TEXT NOT NULL,
        planned_limit                INTEGER NOT NULL DEFAULT 0,
        alert_threshold              INTEGER NOT NULL DEFAULT 80,
        suggested_limit              INTEGER NOT NULL DEFAULT 0,
        base_limit                   INTEGER NOT NULL DEFAULT 0,
        last_month_spent             INTEGER NOT NULL DEFAULT 0,
        was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
        recommendation               TEXT NOT NULL,
        PRIMARY KEY (year_month, category_id),
        FOREIGN KEY (year_month) REFERENCES budget_plans(year_month) ON DELETE CASCADE
      )
    ''');
    // ADR-0027: categories table
    await db.execute('''
      CREATE TABLE categories (
        id                       TEXT PRIMARY KEY,
        name                     TEXT NOT NULL,
        normalized_name          TEXT NOT NULL UNIQUE,
        emoji                    TEXT NOT NULL,
        kind                     TEXT NOT NULL,
        budget_behavior          TEXT NOT NULL,
        quick_amount_min         INTEGER NOT NULL,
        quick_amount_default     INTEGER NOT NULL,
        quick_amount_max         INTEGER NOT NULL,
        voice_phrases_json       TEXT NOT NULL,
        sort_order              INTEGER NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0,
        is_archived              INTEGER NOT NULL DEFAULT 0,
        created_at               INTEGER NOT NULL,
        updated_at               INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_categories_normalized_name ON categories(normalized_name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_categories_is_archived ON categories(is_archived)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE budgets (
          id              TEXT PRIMARY KEY,
          category_name   TEXT NOT NULL,
          monthly_limit   INTEGER NOT NULL,
          alert_threshold INTEGER NOT NULL DEFAULT 80,
          created_at      INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_name)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE recurring_transactions (
          id            TEXT PRIMARY KEY,
          category_name TEXT NOT NULL,
          amount        INTEGER NOT NULL,
          note          TEXT NOT NULL DEFAULT '',
          frequency     TEXT NOT NULL,
          next_run_at   TEXT NOT NULL,
          is_active     INTEGER NOT NULL DEFAULT 1,
          created_at    TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at)');
      await db.execute('ALTER TABLE transactions ADD COLUMN source_recurring_id TEXT');
    }
    if (oldVersion < 6) {
      // Drop FTS5 table if it exists (cleanup from v4/v5 migration)
      await db.execute('DROP TABLE IF EXISTS transactions_fts');
    }
    if (oldVersion < 7) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE quick_templates (
          id              TEXT PRIMARY KEY,
          title           TEXT NOT NULL,
          amount          INTEGER NOT NULL,
          category_name   TEXT NOT NULL,
          note            TEXT NOT NULL DEFAULT '',
          emoji           TEXT NOT NULL,
          is_pinned       INTEGER NOT NULL DEFAULT 0,
          usage_count     INTEGER NOT NULL DEFAULT 0,
          last_used_at    TEXT,
          created_at      TEXT NOT NULL,
          updated_at      TEXT NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_quick_templates_pinned ON quick_templates(is_pinned)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_quick_templates_usage ON quick_templates(usage_count DESC, last_used_at DESC)');
    }
    if (oldVersion < 9) {
      // ADR-0022: add normalized search shadow column
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN search_text_normalized TEXT NOT NULL DEFAULT \'\'');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
      // Backfill existing rows with normalized search text
      final rows = await db.rawQuery(
          'SELECT id, note, category, amount FROM transactions');
      for (final row in rows) {
        final note = row['note'] as String? ?? '';
        final category = row['category'] as String? ?? '';
        final amount = row['amount'] as int? ?? 0;
        final normalized = buildTransactionSearchText(
          note: note,
          category: category,
          amount: amount,
        );
        await db.rawUpdate(
            'UPDATE transactions SET search_text_normalized = ? WHERE id = ?',
            [normalized, row['id']]);
      }
    }
    if (oldVersion < 10) {
      // ADR-0025: monthly budget snapshots
      await db.execute('''
        CREATE TABLE budget_snapshots (
          year_month      TEXT NOT NULL,
          category_name   TEXT NOT NULL,
          limit_amount    INTEGER NOT NULL,
          alert_threshold INTEGER NOT NULL DEFAULT 80,
          created_at      INTEGER NOT NULL,
          PRIMARY KEY (year_month, category_name)
        )
      ''');
    }
    if (oldVersion < 11) {
      // ADR-0026: monthly budget plans
      await db.execute('''
        CREATE TABLE budget_plans (
          year_month            TEXT NOT NULL PRIMARY KEY,
          planned_total_budget  INTEGER NOT NULL DEFAULT 0,
          source                TEXT NOT NULL,
          status                TEXT NOT NULL DEFAULT 'draft',
          created_at            INTEGER NOT NULL,
          updated_at            INTEGER NOT NULL,
          applied_at            INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE budget_plan_items (
          year_month                   TEXT NOT NULL,
          category_name                TEXT NOT NULL,
          planned_limit                INTEGER NOT NULL DEFAULT 0,
          alert_threshold              INTEGER NOT NULL DEFAULT 80,
          suggested_limit              INTEGER NOT NULL DEFAULT 0,
          base_limit                   INTEGER NOT NULL DEFAULT 0,
          last_month_spent             INTEGER NOT NULL DEFAULT 0,
          was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
          recommendation               TEXT NOT NULL,
          PRIMARY KEY (year_month, category_name),
          FOREIGN KEY (year_month) REFERENCES budget_plans(year_month) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 12) {
      // ADR-0027: categories table
      await db.execute('''
        CREATE TABLE categories (
          id                       TEXT PRIMARY KEY,
          name                     TEXT NOT NULL,
          normalized_name          TEXT NOT NULL UNIQUE,
          emoji                    TEXT NOT NULL,
          kind                     TEXT NOT NULL,
          budget_behavior          TEXT NOT NULL,
          quick_amount_min         INTEGER NOT NULL,
          quick_amount_default     INTEGER NOT NULL,
          quick_amount_max         INTEGER NOT NULL,
          voice_phrases_json       TEXT NOT NULL,
          sort_order              INTEGER NOT NULL,
          is_system                INTEGER NOT NULL DEFAULT 0,
          is_archived              INTEGER NOT NULL DEFAULT 0,
          created_at               INTEGER NOT NULL,
          updated_at               INTEGER NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_categories_normalized_name ON categories(normalized_name)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_categories_is_archived ON categories(is_archived)');
    }
    if (oldVersion < 13) {
      // ADR-0029: add category_id to financial tables + rebuild historical tables

      // Step 1: Add category_id to simple tables via ALTER
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN category_id TEXT');
      await db.execute(
          'ALTER TABLE budgets ADD COLUMN category_id TEXT');
      await db.execute(
          'ALTER TABLE recurring_transactions ADD COLUMN category_id TEXT');
      await db.execute(
          'ALTER TABLE quick_templates ADD COLUMN category_id TEXT');

      // Step 2: Seed categories so backfill has something to match against
      // (on fresh v12→v13 installs, categories may not be seeded yet)
      await db.execute('''
        INSERT OR IGNORE INTO categories (id, name, normalized_name, emoji, kind, budget_behavior,
          quick_amount_min, quick_amount_default, quick_amount_max, voice_phrases_json,
          sort_order, is_system, is_archived, created_at, updated_at)
        VALUES
          ('food_out','Ăn ngoài','an ngoai','🍜','spending','flexible',20000,50000,150000,'["ăn ngoài","ăn cơm","ăn"]',10,1,0,1735689600000,1735689600000),
          ('food_home','Ăn nhà','an nha','🍳','spending','flexible',50000,100000,500000,'["ăn nhà","nấu cơm","mua rau"]',20,1,0,1735689600000,1735689600000),
          ('coffee','Cà phê','ca phe','☕','spending','flexible',10000,20000,100000,'["cà phê","cafe","copi"]',30,1,0,1735689600000,1735689600000),
          ('online_shopping','Mua online','mua online','🛒','spending','flexible',10000,50000,500000,'["mua online","shopee","lazada","tiki","mua"]',40,1,0,1735689600000,1735689600000),
          ('housing','Nhà (Điện, nước wifi)','nha dien nuoc wifi','🏠','spending','fixed',3300000,3300000,5000000,'["nhà","điện","nước","wifi"]',50,1,0,1735689600000,1735689600000),
          ('subscription','Subscription','subscription','📱','spending','fixed',100000,200000,500000,'["subscription","github","youtube","phí hàng tháng"]',60,1,0,1735689600000,1735689600000),
          ('entertainment','Giải trí','giai tri','🎬','spending','flexible',30000,50000,200000,'["giải trí","xem phim","chơi game"]',70,1,0,1735689600000,1735689600000),
          ('health','Sức khỏe','suc khoe','🏥','spending','flexible',20000,50000,200000,'["sức khỏe","bác sĩ","thuốc"]',80,1,0,1735689600000,1735689600000),
          ('education','Học tập','hoc tap','📚','spending','flexible',50000,100000,300000,'["học tập","sách","khóa học"]',90,1,0,1735689600000,1735689600000),
          ('investment','Đầu tư','dau tu','📈','investment','excluded',1000000,4000000,20000000,'["đầu tư","etf","quỹ","cổ phiếu"]',100,1,0,1735689600000,1735689600000),
          ('other','Khác','khac','📌','spending','flexible',10000,50000,5000000,'["khác"]',9999,1,0,1735689600000,1735689600000)
      ''');

      // Step 3: Build normalizedName→id map in Dart (avoids calling Dart fn from SQL)
      final catRows = await db.rawQuery(
          'SELECT id, normalized_name FROM categories WHERE is_archived = 0');
      final activeCatMap = <String, String>{};
      for (final r in catRows) {
        activeCatMap[r['normalized_name'] as String] = r['id'] as String;
      }
      final allCatRows = await db.rawQuery(
          'SELECT id, normalized_name FROM categories');
      final allCatMap = <String, String>{};
      for (final r in allCatRows) {
        allCatMap[r['normalized_name'] as String] = r['id'] as String;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final placeholderCreated = <String, String>{}; // name → placeholderId

      String resolveCategoryId(String categoryName) {
        if (categoryName.isEmpty) return 'other';
        final norm = normalizeVietnameseSearchText(categoryName);
        // Try active first
        if (activeCatMap.containsKey(norm)) {
          return activeCatMap[norm]!;
        }
        // Try any category (archived included)
        if (allCatMap.containsKey(norm)) {
          return allCatMap[norm]!;
        }
        // Create/retrieve placeholder
        if (!placeholderCreated.containsKey(categoryName)) {
          final placeholderId = 'placeholder_${norm}_${nowMs}';
          placeholderCreated[categoryName] = placeholderId;
        }
        return placeholderCreated[categoryName]!;
      }

      // Step 4: Backfill transactions
      final txRows = await db.rawQuery(
          'SELECT id, category FROM transactions WHERE category_id IS NULL OR category_id = ""');
      for (final row in txRows) {
        final id = row['id'] as String;
        final catName = row['category'] as String;
        final catId = resolveCategoryId(catName);
        await db.update('transactions', {'category_id': catId},
            where: 'id = ?', whereArgs: [id]);
      }

      // Step 5: Backfill budgets
      final budgetRows = await db.rawQuery(
          'SELECT id, category_name FROM budgets WHERE category_id IS NULL OR category_id = ""');
      for (final row in budgetRows) {
        final id = row['id'] as String;
        final catName = row['category_name'] as String;
        final catId = resolveCategoryId(catName);
        await db.update('budgets', {'category_id': catId},
            where: 'id = ?', whereArgs: [id]);
      }

      // Step 6: Backfill recurring_transactions
      final recRows = await db.rawQuery(
          'SELECT id, category_name FROM recurring_transactions WHERE category_id IS NULL OR category_id = ""');
      for (final row in recRows) {
        final id = row['id'] as String;
        final catName = row['category_name'] as String;
        final catId = resolveCategoryId(catName);
        await db.update('recurring_transactions', {'category_id': catId},
            where: 'id = ?', whereArgs: [id]);
      }

      // Step 7: Backfill quick_templates
      final qtRows = await db.rawQuery(
          'SELECT id, category_name FROM quick_templates WHERE category_id IS NULL OR category_id = ""');
      for (final row in qtRows) {
        final id = row['id'] as String;
        final catName = row['category_name'] as String;
        final catId = resolveCategoryId(catName);
        await db.update('quick_templates', {'category_id': catId},
            where: 'id = ?', whereArgs: [id]);
      }

      // Step 8: Insert placeholder categories for unknown names
      for (final entry in placeholderCreated.entries) {
        final catName = entry.key;
        final placeholderId = entry.value;
        final norm = normalizeVietnameseSearchText(catName);
        await db.execute('''
          INSERT OR IGNORE INTO categories
            (id, name, normalized_name, emoji, kind, budget_behavior,
             quick_amount_min, quick_amount_default, quick_amount_max,
             voice_phrases_json, sort_order, is_system, is_archived,
             created_at, updated_at)
          VALUES (?, ?, ?, '📌', 'spending', 'flexible',
                  10000, 50000, 5000000, ?, 9998, 0, 1,
                  ?, ?)
        ''', [placeholderId, catName, norm, '["$catName"]', nowMs, nowMs]);
      }

      // Step 9: Replace budgets UNIQUE index from category_name → category_id
      await db.execute('DROP INDEX IF EXISTS idx_budgets_category');
      await db.execute(
          'CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_id)');

      // Step 10: Add category_id indexes
      await db.execute(
          'CREATE INDEX idx_transactions_category_id ON transactions(category_id)');
      await db.execute(
          'CREATE INDEX idx_recurring_category_id ON recurring_transactions(category_id)');

      // Step 11: Rebuild budget_snapshots with new PK (year_month, category_id)
      // SQLite cannot ALTER to change PKs. Rebuild via create + copy + drop + rename.
      await db.execute('''
        CREATE TABLE budget_snapshots_v2 (
          year_month      TEXT NOT NULL,
          category_name   TEXT NOT NULL,
          category_id    TEXT NOT NULL,
          limit_amount  INTEGER NOT NULL,
          alert_threshold INTEGER NOT NULL DEFAULT 80,
          created_at    INTEGER NOT NULL,
          PRIMARY KEY (year_month, category_id)
        )
      ''');

      final snapshotRows = await db.rawQuery('SELECT * FROM budget_snapshots');
      for (final row in snapshotRows) {
        final catName = row['category_name'] as String;
        final catId = resolveCategoryId(catName);
        await db.insert('budget_snapshots_v2', {
          'year_month': row['year_month'],
          'category_name': catName,
          'category_id': catId,
          'limit_amount': row['limit_amount'],
          'alert_threshold': row['alert_threshold'],
          'created_at': row['created_at'],
        });
      }
      await db.execute('DROP TABLE budget_snapshots');
      await db.execute('ALTER TABLE budget_snapshots_v2 RENAME TO budget_snapshots');

      // Step 12: Rebuild budget_plan_items with new PK (year_month, category_id)
      await db.execute('''
        CREATE TABLE budget_plan_items_v2 (
          year_month                   TEXT NOT NULL,
          category_name                TEXT NOT NULL,
          category_id                  TEXT NOT NULL,
          planned_limit                INTEGER NOT NULL DEFAULT 0,
          alert_threshold              INTEGER NOT NULL DEFAULT 80,
          suggested_limit              INTEGER NOT NULL DEFAULT 0,
          base_limit                   INTEGER NOT NULL DEFAULT 0,
          last_month_spent             INTEGER NOT NULL DEFAULT 0,
          was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
          recommendation               TEXT NOT NULL,
          PRIMARY KEY (year_month, category_id),
          FOREIGN KEY (year_month) REFERENCES budget_plans(year_month) ON DELETE CASCADE
        )
      ''');

      final planItemRows = await db.rawQuery('SELECT * FROM budget_plan_items');
      for (final row in planItemRows) {
        final catName = row['category_name'] as String;
        final catId = resolveCategoryId(catName);
        await db.insert('budget_plan_items_v2', {
          'year_month': row['year_month'],
          'category_name': catName,
          'category_id': catId,
          'planned_limit': row['planned_limit'],
          'alert_threshold': row['alert_threshold'],
          'suggested_limit': row['suggested_limit'],
          'base_limit': row['base_limit'],
          'last_month_spent': row['last_month_spent'],
          'was_over_budget_last_month': row['was_over_budget_last_month'],
          'recommendation': row['recommendation'],
        });
      }
      await db.execute('DROP TABLE budget_plan_items');
      await db.execute('ALTER TABLE budget_plan_items_v2 RENAME TO budget_plan_items');
    }
  }

  /// Test-only: inject an already-opened database
  @visibleForTesting
  set testDatabase(Database db) {
    _database = db;
  }

  /// Test-only: override the database path for migration tests. When set,
  /// _initDatabase uses this path instead of `getDatabasesPath()/qlct.db`.
  /// Each test gets its own path so file-locking across test runs is avoided.
  @visibleForTesting
  set testPathOverride(String? path) {
    _testPathOverride = path;
  }

  /// Test-only: returns the currently held database (assumes non-null)
  @visibleForTesting
  Future<Database> get rawDatabase async => _database!;

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction((txn) => action(txn));
  }
}

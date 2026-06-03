# ADR-0004: SQLite Storage with UUID Primary Keys and DataSource Pattern

**Status**: accepted

## Context

The app currently stores all transactions as a single JSON-encoded list in `SharedPreferences` via `StorageService`. This works for a simple use case but has fundamental limitations that block upcoming features:

- **No query capability**: filtering by date, category, or amount range requires loading the entire list into memory and filtering client-side (`TransactionRepositoryImpl` lines 44-67)
- **No referential integrity**: future tables (`recurring_rules`, `budgets`) need foreign keys to `transactions`
- **Single-write bottleneck**: adding or deleting a transaction rewrites the entire list (O(n) serialization)
- **No atomicity**: concurrent writes could corrupt the JSON blob
- **No ID safety**: `DateTime.now().millisecondsSinceEpoch` as ID risks collisions if two transactions are created in the same millisecond

The upcoming features (recurring transactions, budget tracking, advanced query/filter) require a proper relational database.

## Decision

We migrate transaction storage from `SharedPreferences` (JSON) to **SQLite via `sqflite`**, using **UUID strings as primary keys**, and introducing a **DataSource abstraction layer**.

### 1. Library: sqflite

**Chosen**: `sqflite` (raw SQL) over `drift` (ORM with code-gen).

Rationale:
- The app already uses `build_runner` (freezed, json_serializable), so drift's code-gen would integrate seamlessly — but for a single table (`transactions`) with 6 columns, the overhead of defining DAOs and `.drift` files adds complexity without proportional benefit.
- `sqflite` is battle-tested (5 years, 3k+ GitHub stars, runs on all Flutter platforms).
- Raw SQL keeps the schema transparent — a developer can inspect the `.db` file with any SQLite tool.
- Adding drift later is possible if query complexity grows (recurring, budgets, reports).

**Rejected**: `drift` — unnecessary ceremony for current scale. `floor` — maintainer archived the repo.

### 2. ID strategy: UUID (String)

**Chosen**: `TEXT PRIMARY KEY` with UUID v4 strings, replacing `int` IDs.

Previously: `id: int` = `DateTime.now().millisecondsSinceEpoch` (e.g., `1749001234567`).

Rationale:
- **Future-proof for multi-device sync**: UUIDs never collide across devices. If we add cloud sync (a stated future goal), `AUTOINCREMENT INTEGER` would produce conflicting IDs on two devices that both insert a transaction offline.
- **Clean migration path**: existing SharedPreferences IDs (large millisecond timestamps like `1749001234567`) coexist with new UUIDs (`550e8400-e29b-41d4-a716-446655440000`) without conflict — different format, no collision.
- **No leaky enumerability**: `GET /api/transaction/42` reveals order count. UUID hides it.
- **Consistent across all future tables**: `recurring_rules.id`, `budgets.id` will also use UUIDs.

**Cost**: TEXT index is slightly slower than INTEGER index. For ≤10k rows this is negligible. Debugging is harder ("which transaction is `a1b2c3d4-...`?").

**Rejected**: `INTEGER PRIMARY KEY AUTOINCREMENT` — trivial now, catastrophic later if sync is added.

### 3. Architecture: DataSource pattern

**Chosen**: Abstract `TransactionLocalDataSource` + `SqliteTransactionDataSource` implementation.

```
TransactionRepositoryImpl
  └── TransactionLocalDataSource (abstract, new layer)
        └── SqliteTransactionDataSource (sqflite impl, new)
  └── StorageService (kept for settingsKey only)
```

Previously: `TransactionRepositoryImpl` called `StorageService` directly (SharedPreferences).

Rationale:
- `StorageService` is kept for `settingsKey` (non-relational key-value data).
- Separating SQLite logic into a DataSource layer prevents SQL code from leaking into the repository and allows swapping implementations (e.g., in-memory DB for tests, or cloud-backed later).
- When `recurring_rules` and `budgets` are added (future weeks), each gets its own DataSource, sharing the same `DatabaseHelper` for connection management.

**Rejected**: Embedding SQLite directly in `TransactionRepositoryImpl` — duplicates connection/migration logic across repositories. No clear boundary.

### 4. Schema: transactions v1

```sql
CREATE TABLE transactions (
  id         TEXT PRIMARY KEY,       -- UUID v4
  amount     INTEGER NOT NULL,       -- VND, no decimals
  category   TEXT NOT NULL,          -- references Category.name (not FK yet)
  emoji      TEXT NOT NULL DEFAULT '',
  date       TEXT NOT NULL,          -- ISO 8601 string
  note       TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL       -- Unix timestamp ms (sort key)
);

CREATE INDEX idx_transactions_date ON transactions(date);
CREATE INDEX idx_transactions_category ON transactions(category);
```

- `date` stored as TEXT (ISO 8601) — `DateTime.toIso8601String()` maps directly, lexicographic sort is correct, human-readable in the DB file.
- `created_at` as INTEGER for fast range queries and deterministic sort order (two transactions can have the same `date` string but different `created_at`).

### 5. Migration from SharedPreferences

One-time, flag-guarded: check `SharedPreferences.containsKey('migrated_to_sqlite_v1')`. If false, read old transactions from `'transactions'` key, batch-insert into SQLite (preserving original IDs), set flag, delete old key.

Migration is idempotent: if it fails mid-way (crash), the flag is only set after successful batch insert. Next launch retries.

## Consequences

- `Transaction.id` changes from `int` to `String` — all references must update (`ExpenseViewModel.deleteTransaction`, `transaction_list_widget`, tests).
- `build_runner` must re-run to regenerate `transaction.freezed.dart` and `transaction.g.dart`.
- `TransactionRepositoryImpl` no longer uses `_cachedTransactions` (SQLite is the cache). Query methods (`getByDate`, `getByCategory`, `getByDateRange`) delegate to SQL WHERE clauses instead of in-memory filtering.
- `StorageService` and `shared_preferences` dependency remain — they still serve `settingsKey`.
- Existing unit tests for `TransactionRepositoryImpl` must be rewritten (was mocking `StorageService`, must now mock `TransactionLocalDataSource`).
- `ExpenseViewModel` holds its own `_transactions` list (loaded once via `getAll()`), so stats calculation (`_calculateStats()`) stays in-memory and unchanged.

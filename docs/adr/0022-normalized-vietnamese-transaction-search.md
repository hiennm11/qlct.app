# ADR-0022: Normalized Vietnamese Transaction Search

**Date:** 2026-06-07
**Status:** Accepted
**Author:** hiennm11
**Revisits:** ADR-0009 (Search fallback to LIKE), ADR-0018 (Remove pass-through repositories)

## Context

Current transaction search uses SQLite `LIKE` on raw fields:

```sql
WHERE note LIKE ? OR category LIKE ? OR CAST(amount AS TEXT) LIKE ?
```

This is compatible with Android SQLite, but the user experience is weak for Vietnamese:

- Search is accent-sensitive in practice: `ca phe` does not reliably match `Cà phê`.
- Search can require exact Vietnamese tone marks.
- Case/collation behavior depends on SQLite/device details.
- FTS5 was already attempted in ADR-0009 and rejected after real-device failure: `no such module: fts5`.

We need better search while keeping the architecture small. No custom search engine. No SQLite optional extensions.

Current architecture after ADR-0018:

```text
Widget
  → ExpenseViewModel
  → TransactionLocalDataSource
  → SqliteTransactionDataSource
  → SQLite
```

Search query behavior belongs in the DataSource seam, not the ViewModel or widgets.

## Decision

Implement Vietnamese accent-insensitive search with a normalized shadow column on `transactions`.

### 1. Add a pure text normalizer in `core/`

Create:

```text
lib/core/vietnamese_text_normalizer.dart
```

Responsibilities:

- Lowercase text.
- Convert Vietnamese accented characters to ASCII base characters.
- Convert `đ` / `Đ` to `d`.
- Collapse repeated whitespace.
- Trim leading/trailing whitespace.
- Keep digits so amount search still works.

Example mappings:

| Input | Normalized |
|-------|------------|
| `Cà phê Highlands` | `ca phe highlands` |
| `Ăn ngoài` | `an ngoai` |
| `Đầu tư` | `dau tu` |
| `  Cà   phê  ` | `ca phe` |

Expose small pure helpers:

```dart
String normalizeVietnameseSearchText(String input);

String buildTransactionSearchText({
  required String note,
  required String category,
  required int amount,
});
```

`buildTransactionSearchText` combines the searchable transaction fields:

```text
note category amount
```

Scope stays the same as current search:

- `note`
- `category`
- `amount`

Do not add `emoji`, date, or recurring source to search for this slice.

### 2. Add `search_text_normalized` to `transactions`

Bump database version from v8 to v9.

Migration:

```sql
ALTER TABLE transactions
ADD COLUMN search_text_normalized TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized
ON transactions(search_text_normalized);
```

Backfill existing rows in Dart after adding the column:

1. Query `id`, `note`, `category`, `amount` from `transactions`.
2. Build normalized search text with `buildTransactionSearchText`.
3. Update `search_text_normalized` per row.

Rationale: SQLite SQL alone is not suitable for robust Vietnamese accent stripping.

New installs should include the column directly in `_onCreate`.

### 3. Keep public DataSource API as `search(query)`

Do not add a parallel `searchNormalized(query)` unless a future caller needs both behaviors.

Current interface remains:

```dart
Future<List<Transaction>> search(String query);
```

But its implementation changes from raw `LIKE` to normalized `LIKE`:

```dart
final normalized = normalizeVietnameseSearchText(query);
final likePattern = '%$normalized%';
```

SQLite query:

```sql
WHERE search_text_normalized LIKE ?
ORDER BY created_at DESC
```

Because `amount` is included in `search_text_normalized`, no separate `CAST(amount AS TEXT)` branch is required.

### 4. Keep shadow column synced on all write paths

Every transaction row write must populate `search_text_normalized`:

- `SqliteTransactionDataSource.add`
- `SqliteTransactionDataSource.update`
- `SqliteTransactionDataSource.bulkInsert`
- backup restore flows that insert through the transaction DataSource
- migration v9 backfill for old rows

Preferred implementation point: `transactionToRow()` mapper, because all normal datasource writes already pass through it.

This keeps the sync rule centralized and prevents callers from manually remembering the shadow column.

### 5. ViewModel and widgets stay orchestration-only

`ExpenseViewModel.setSearchQuery()` should not normalize Vietnamese text.

It remains responsible for:

- trim empty query
- loading state
- calling `_dataSource.search(trimmed)`
- storing `_searchResults`
- invalidating filtered cache
- error handling

Widgets only collect input and debounce search. They do not normalize.

## Consequences

### Positive

- Search supports common Vietnamese no-accent input: `ca phe` → `Cà phê`.
- Works on all Android SQLite builds because it uses normal table columns and `LIKE` only.
- Keeps architecture small: pure helper + shadow column + DataSource query.
- Query logic remains in `TransactionLocalDataSource`, matching ADR-0018.
- No FTS5 triggers, virtual tables, or optional SQLite modules.

### Negative

- Adds a denormalized column that must stay synced on writes.
- Requires DB migration v9 and backfill.
- `LIKE '%query%'` remains a scan-like query for contains search. The index has limited value for leading-wildcard patterns, but the dataset size is acceptable for a personal expense tracker.
- No ranking. Results stay ordered by `created_at DESC`.

### Risks

- If any write path bypasses `transactionToRow()`, `search_text_normalized` can become stale.
- If the normalizer misses Vietnamese characters, search will have gaps.
- If old rows are not backfilled correctly, search works only for new/updated transactions.

## Tests

### Core normalizer tests

- `Cà phê` → `ca phe`
- `Ăn ngoài` → `an ngoai`
- `Đầu tư` → `dau tu`
- uppercase input lowercases correctly
- repeated whitespace collapses
- digits are preserved

### Datasource tests

- Search `ca phe` matches transaction category `Cà phê`.
- Search `cà phê` also matches the same row.
- Search `an ngoai` matches `Ăn ngoài`.
- Search `dau tu` matches `Đầu tư`.
- Search note without accents matches accented note.
- Search amount text matches amount.
- Updating note/category/amount updates `search_text_normalized`.
- `bulkInsert` populates `search_text_normalized`.

### Migration tests

- v8 database upgrades to v9 with `search_text_normalized` column.
- Existing rows are backfilled.
- Existing rows become searchable by no-accent query after migration.

## Implementation Order

1. Add `VietnameseTextNormalizer` helper and unit tests.
2. Add `search_text_normalized` to `transactions` `_onCreate` schema.
3. Add v9 migration with Dart backfill.
4. Update `transactionToRow()` to include normalized search text.
5. Update `SqliteTransactionDataSource.search()` to normalize query and search the shadow column.
6. Add datasource tests for add/update/bulk/search behavior.
7. Add migration regression test.
8. Update `CONTEXT.md` search vocabulary and architecture notes.

## Rejected Options

### A. Retry FTS5

Rejected. ADR-0009 recorded real-device failure on Android: `no such module: fts5`. Optional SQLite extensions are not safe for this app.

### B. Normalize in ViewModel

Rejected. Search semantics are query/data concern. Putting normalization in `ExpenseViewModel` leaks persistence behavior upward and makes future datasource implementations harder to swap.

### C. Normalize only the query, keep raw columns

Rejected. `ca phe LIKE Cà phê` still does not match. Both sides need the same normalized representation.

### D. In-memory search over loaded transactions

Rejected. Current app has DB pagination. In-memory search would only search loaded pages or force full-table loads, weakening ADR-0017 performance work.

### E. Add a separate search engine/package

Rejected. Overkill for personal expense tracker scale. A normalized shadow column is enough.

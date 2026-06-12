# ADR-0029: Category ID Financial Table Migration

**Date:** 2026-06-10
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0027 introduced the persisted `categories` table as the source of truth for category metadata. Each category has a stable `Category.id` string:

```text
food_out
food_home
coffee
online_shopping
housing
subscription
entertainment
health
education
investment
other
```

Future custom categories use UUID string IDs.

ADR-0028 added category management for safe fields only: emoji, quick amount range, voice phrases, sort order, and archive status. It intentionally deferred rename, custom category creation, hard delete, and category behavior editing because financial tables still identify categories by display name.

Current financial category references are legacy name snapshots:

| Table | Current category column |
|---|---|
| `transactions` | `category` |
| `budgets` | `category_name` |
| `recurring_transactions` | `category_name` |
| `quick_templates` | `category_name` |
| `budget_snapshots` | `category_name` |
| `budget_plan_items` | `category_name` |

This blocks safe category rename and custom category creation because names are both display labels and identity keys.

The next phase must migrate financial rows to stable category identity while preserving historical display text for audit, backup, export, and old-data compatibility.

## Decision

Add `category_id TEXT` references to all financial tables and migrate the full app stack to use `Category.id` as category identity.

This is Phase 2.6 of the category refactor.

### 1. Category reference column

Add a new column to every financial table that references a category:

```text
category_id TEXT
```

Affected tables:

```text
transactions
budgets
recurring_transactions
quick_templates
budget_snapshots
budget_plan_items
```

`category_id` is `TEXT`, not `INTEGER`, because `categories.id` is already a stable string primary key. Using the existing category ID avoids adding a numeric surrogate key to `categories` and keeps seeded semantic IDs plus future UUID custom IDs in one identity system.

### 2. Keep legacy name columns as snapshots

Do not drop the existing category name columns.

Keep them as denormalized category name snapshots:

```text
transactions.category
budgets.category_name
recurring_transactions.category_name
quick_templates.category_name
budget_snapshots.category_name
budget_plan_items.category_name
```

Rationale:

- Historical transactions should keep the label visible at the time they were recorded.
- Export and backup can remain inspectable without requiring joins.
- Restore from older backups can still provide category names while `category_id` is backfilled.
- Future category rename can update live category labels without rewriting history unless explicitly desired.

### 3. Do not rename `transactions.category`

`transactions` currently uses `category`, while the other financial tables use `category_name`.

Do not rename `transactions.category` to `category_name` in this phase.

Rationale:

- The column already has production data and indexes.
- Renaming adds migration risk without changing domain behavior.
- The new identity column `category_id` is consistent across all tables, which is the important boundary.

### 4. Database migration version

Implement this as one SQLite migration version:

```text
v13: add category_id references + backfill + identity indexes/constraints
```

The migration should run atomically through the existing `DatabaseHelper` migration flow.

Migration work:

1. Add `category_id TEXT` to:
   - `transactions`
   - `budgets`
   - `recurring_transactions`
   - `quick_templates`
2. Rebuild tables that need primary-key changes:
   - `budget_snapshots`
   - `budget_plan_items`
3. Backfill every `category_id` from the persisted `categories` catalog.
4. Create indexes on new `category_id` columns where lookup/filtering needs them.
5. Replace name-based uniqueness/primary-key constraints with ID-based constraints where identity semantics require it.

### 5. Backfill rule

For each existing financial row:

```text
legacy category name → normalize Vietnamese text → match categories.normalized_name → category_id
```

Examples:

```text
transactions.category                  → category_id
budgets.category_name                  → category_id
recurring_transactions.category_name   → category_id
quick_templates.category_name          → category_id
budget_snapshots.category_name         → category_id
budget_plan_items.category_name        → category_id
```

Backfill must preserve the original name snapshot column unchanged.

### 6. Unknown legacy category names

If a legacy name does not match any row in `categories`, create a placeholder category instead of collapsing it into `other` or leaving `category_id` null.

Placeholder category policy:

```text
id              = generated UUID string
name            = legacy display name
normalizedName  = normalized legacy name, unique
emoji           = default fallback emoji
kind            = spending
budgetBehavior  = flexible
quick amounts   = conservative default range
voicePhrases    = [legacy display name]
sortOrder       = after current active categories, before other if possible
isSystem        = false
isArchived      = true
createdAt       = migration time
updatedAt       = migration time
```

Rationale:

- Historical data remains attached to a real category identity.
- Distinct unknown names stay distinct.
- Users can later inspect, unarchive, rename, or merge custom categories when those flows exist.
- `other` remains a deliberate fallback, not a data-loss sink.

### 7. Budget uniqueness

`budgets` currently enforces one live budget per category name:

```text
UNIQUE(category_name)
```

Replace that identity constraint with:

```text
UNIQUE(category_id)
```

Rationale: after this migration, category identity is `Category.id`; category names are snapshots.

### 8. Historical composite keys

`budget_snapshots` and `budget_plan_items` currently use composite primary keys based on category name:

```text
budget_snapshots:  PRIMARY KEY (year_month, category_name)
budget_plan_items: PRIMARY KEY (year_month, category_name)
```

Rebuild both tables so identity uses category ID:

```text
budget_snapshots:  PRIMARY KEY (year_month, category_id)
budget_plan_items: PRIMARY KEY (year_month, category_id)
```

Keep `category_name` in both tables as the snapshot label.

Rationale:

- One category should have one snapshot row per month even if display names change later.
- One category should have one plan item per planned month.
- SQLite cannot alter primary keys in place, so these tables must be rebuilt with copy/drop/rename semantics.

### 9. Model migration

Add `categoryId` to all persisted financial models that reference a category:

```text
Transaction.categoryId
Budget.categoryId
RecurringTransaction.categoryId
QuickTemplate.categoryId
BudgetSnapshot.categoryId
BudgetPlanItem.categoryId
```

Keep existing category name fields as snapshots:

```text
Transaction.category
Budget.categoryName
RecurringTransaction.categoryName
QuickTemplate.categoryName
BudgetSnapshot.categoryName
BudgetPlanItem.categoryName
```

Runtime identity comparisons should move to `categoryId`. Display text may continue to use snapshot names where historical accuracy matters, or current `Category.name` where live configuration matters.

### 10. ViewModel and widget migration

Migrate the app stack to pass category IDs through write paths.

Affected flows include:

```text
quick input transaction creation
custom input transaction creation
transaction edit
budget edit / bulk edit
recurring create / edit
quick template create / edit / use
monthly review category filter tap-through
monthly budget planning item edits
backup restore refresh paths
```

After this phase, widgets and ViewModels should not depend on category display names as identity.

The legacy bridge:

```text
CategoryViewModel.categoryByName(String name)
```

should be removed once all production call sites have migrated to ID-based lookup.

### 11. Backup schema

Bump backup schema to include category IDs in financial records.

Suggested new backup schema version:

```text
BackupData schema v7
```

Rules:

- New backups include both `categoryId` and the existing category name snapshot.
- Restoring old backups without `categoryId` backfills category IDs using the same normalized-name matching and placeholder creation policy as DB v13 migration.
- Restoring new backups must restore categories before financial rows so category IDs are resolvable.
- Unknown category IDs in a backup should not orphan financial rows; restore should create or preserve matching category records when possible.

### 12. Search and export

Transaction search still uses the snapshot category name text.

`transactions.search_text_normalized` continues to include:

```text
note + category snapshot + amount
```

CSV/JSON quick export may keep using the snapshot category label for readability.

Full backup uses both identity and snapshot.

### 13. Out of scope

This ADR does not add:

```text
category rename UI
custom category creation UI
hard delete / merge category UI
CategoryKind editing UI
BudgetBehavior editing UI
rollover behavior
```

Those are unlocked by this migration but remain separate phases.

## Consequences

### Positive

- Category identity is stable across transactions, budgets, snapshots, plans, recurring rules, and templates.
- Category rename becomes possible without breaking financial links.
- Unknown legacy names become recoverable placeholder categories instead of being lost.
- Budget and planning constraints use real category identity instead of display labels.
- Backup/restore can support both old name-based data and new ID-based data.

### Negative

- This is a large full-stack migration touching storage, models, backup, ViewModels, and widgets.
- Financial rows now duplicate category identity and snapshot label.
- Rebuilding historical tables increases migration risk and requires focused tests.
- Placeholder categories can add archived catalog entries that users did not explicitly create.

### Required verification

- SQLite migration v12 → v13 with normal seeded categories.
- SQLite migration v12 → v13 with unknown legacy category names.
- `budget_snapshots` PK changes preserve historical rows.
- `budget_plan_items` PK changes preserve draft/applied plan rows.
- `budgets` uniqueness moves from category name to category ID.
- Transaction create/edit uses `categoryId` and preserves snapshot `category`.
- Backup schema v6 restore backfills category IDs.
- Backup schema v7 round-trip preserves category IDs and snapshots.
- Full focused tests for category, transaction, budget, recurring, templates, planning, review, backup/restore.

## Deferred

- Category rename and custom category creation.
- Category merge or hard delete flows.
- User-facing placeholder cleanup workflow.
- Advanced behavior editing (`CategoryKind`, `BudgetBehavior`).
- Phase 3 budget rollover.

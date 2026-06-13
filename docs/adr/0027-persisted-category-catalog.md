# ADR-0027: Persisted Category Catalog

**Date:** 2026-06-10
**Status:** Accepted
**Author:** hiennm11

## Context

`Category.predefined` is currently the runtime source of truth for spending categories. The list is hardcoded in `lib/models/category.dart` and is referenced throughout the app:

- quick input amount sliders
- custom input dropdowns
- voice category matching
- recurring transaction forms
- quick templates
- budget status calculation
- monthly review investment exclusion
- monthly budget planning
- future rollover eligibility

This was acceptable while categories were a fixed seed list. It now blocks the next budget phase:

- rollover must be opt-in per category, not global
- rollover eligibility should depend on category behavior, not scattered hardcoded allowlists
- user category customization is hard while `name` is treated as identity
- renaming a category would break historical references because transactions, budgets, snapshots, plans, recurring rules, and templates currently store category names

ADR-0025 added monthly budget snapshots. ADR-0026 added monthly budget planning. Before adding rollover/bucket behavior, categories need a persisted catalog and stable identity.

## Decision

Add a persisted category catalog as the app's category source of truth.

This ADR intentionally covers the first infrastructure phase. It does **not** immediately migrate all financial tables to `categoryId`, and it does **not** expose rename/archive/delete UI yet.

### 1. Category identity

Categories have stable IDs.

```text
Category.id   = immutable identity
Category.name = current display label
```

Default seeded categories use stable semantic IDs:

```text
food_out           Ăn ngoài
food_home          Ăn nhà
coffee             Cà phê
online_shopping    Mua online
housing            Nhà (Điện, nước, wifi)
subscription       Subscription
entertainment      Giải trí
health             Sức khỏe
education          Học tập
investment         Đầu tư
other              Khác
```

Future user-created categories use UUIDs.

Rationale: stable IDs make restore/merge, legacy backfill, category rename, and future categoryId migration deterministic. UUIDs remain appropriate for user-created categories where no semantic seed identity exists.

### 2. Phase boundary

Category migration is phased.

```text
Phase 2.5A:
  - add persisted categories table
  - seed default categories from the old hardcoded list
  - app reads categories from DB through CategoryViewModel
  - full backup schema includes categories
  - financial tables still store legacy category names
  - no user rename/archive/delete UI

Phase 2.5B:
  - category management UI after the DB source of truth is stable
  - edit presentation/input fields only

Phase 2.6:
  - add categoryId references to financial tables
  - backfill from legacy names
  - transaction keeps categoryNameSnapshot for audit/export

Phase 3:
  - rollover uses category policy and category behavior
```

Rationale: a big-bang migration would touch nearly every domain flow at once: transactions, budget, snapshots, plans, recurring rules, templates, backup/restore, voice, review, and charts. The phased approach keeps each slice testable and reversible.

### 3. Category model

Persist this shape:

```text
Category
  id: String
  name: String
  normalizedName: String
  emoji: String
  kind: CategoryKind
  budgetBehavior: BudgetBehavior
  quickAmountMin: int
  quickAmountDefault: int
  quickAmountMax: int
  voicePhrases: List<String>
  sortOrder: int
  isSystem: bool
  isArchived: bool
  createdAt: DateTime
  updatedAt: DateTime
```

Rename the existing amount/voice fields when introducing the persisted model:

```text
minAmount      → quickAmountMin
defaultAmount  → quickAmountDefault
maxAmount      → quickAmountMax
phrases        → voicePhrases
```

Rationale: these values configure quick input and voice input. They are not monthly budget defaults. The name must prevent future confusion with budget planning.

### 4. Category behavior vocabulary

Use two enums instead of `isInvestment` plus multiple booleans.

```text
CategoryKind:
  spending
  investment

BudgetBehavior:
  flexible
  fixed
  excluded
```

Derived rules:

```text
includedInSpendingBudget = kind == spending && budgetBehavior != excluded
rolloverEligible         = kind == spending && budgetBehavior == flexible
fixedExpenseCandidate    = kind == spending && budgetBehavior == fixed
investmentExcluded       = kind == investment
```

Rationale: booleans such as `isInvestment`, `isFixedExpense`, `includeInBudget`, and `isRolloverEligible` can create invalid combinations. The two-enum model keeps the domain explicit while remaining flexible enough for planning and rollover.

### 5. Seed category behavior

Initial default category mapping:

| Category | `CategoryKind` | `BudgetBehavior` |
|---|---|---|
| Ăn ngoài | spending | flexible |
| Ăn nhà | spending | flexible |
| Cà phê | spending | flexible |
| Mua online | spending | flexible |
| Giải trí | spending | flexible |
| Sức khỏe | spending | flexible |
| Học tập | spending | flexible |
| Nhà (Điện, nước, wifi) | spending | fixed |
| Subscription | spending | fixed |
| Đầu tư | investment | excluded |
| Khác | spending | flexible |

`Khác` remains flexible, but rollover remains default `none` when rollover is later added. Flexible means the category can participate in budget/planning behavior; it does not automatically opt into rollover.

### 6. System categories

Default seeded categories are system categories.

```text
isSystem = true  for seeded default categories
isSystem = false for future custom categories
```

Rules:

- system category IDs are immutable
- system categories cannot be hard deleted
- system categories may be archived later, except `other`
- `other` is always active and acts as fallback
- `investment` may be archived from new-entry flows later, but keeps `kind=investment` and `budgetBehavior=excluded`

Future category management can edit system category presentation/input fields after the categoryId migration is safe:

- name
- emoji
- quick amount range
- voice phrases
- sort order
- archive/unarchive, except `other`

Do not expose normal UI for editing `kind` or `budgetBehavior` in the first management phase. Those fields affect review, budget planning, and rollover semantics and require a later advanced flow.

### 7. Archive and delete semantics

Future category deletion semantics:

```text
unused custom category → hard delete allowed
used category          → archive only
system category        → archive only, never hard delete
other                  → never archive, never hard delete
```

Archived categories:

- are hidden from new-entry flows by default
- remain visible in history/detail/filter when referenced
- can be restored/unarchived

Rationale: financial history must not be orphaned by category deletion.

### 8. Name uniqueness

Category names are globally unique by normalized Vietnamese name, including archived categories.

Normalization follows the same semantics as transaction search normalization:

```text
lowercase
trim
collapse whitespace
remove Vietnamese accents
đ/Đ → d
```

Examples:

```text
"Cà phê" == "ca phe" == " CÀ   PHÊ "
```

Persist `normalizedName` in the DB and enforce uniqueness with a DB constraint/index.

Rationale: duplicate category names make dropdowns, voice matching, legacy backfill, and restore merge ambiguous.

### 9. Storage

Add SQLite table in the next DB version:

```sql
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL UNIQUE,
  emoji TEXT NOT NULL,
  kind TEXT NOT NULL,
  budget_behavior TEXT NOT NULL,
  quick_amount_min INTEGER NOT NULL,
  quick_amount_default INTEGER NOT NULL,
  quick_amount_max INTEGER NOT NULL,
  voice_phrases_json TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  is_system INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

`voicePhrases` is stored as compact JSON in `voice_phrases_json`, not in a separate phrase table.

Rationale: voice matching currently loads all categories and runs in memory. SQL phrase search/indexing is unnecessary for this app phase.

Seed defaults with `INSERT OR IGNORE` by `id`.

### 10. Sort order

`sortOrder` is the source of UI order.

Seed with gaps of 10:

```text
10   Ăn ngoài
20   Ăn nhà
30   Cà phê
40   Mua online
50   Nhà (Điện, nước, wifi)
60   Subscription
70   Giải trí
80   Sức khỏe
90   Học tập
100  Đầu tư
9999 Khác
```

New-entry flows:

```text
WHERE is_archived = 0
ORDER BY sort_order ASC, name ASC
```

Future custom categories are inserted before `other`. `other` stays last.

### 11. DataSource and ViewModel

Add:

```text
CategoryLocalDataSource
SqliteCategoryDataSource
category_row_mapper.dart
CategoryViewModel
```

`CategoryViewModel` is app-level state provided through Provider. Do not block `runApp` waiting for category load.

Suggested ViewModel surface:

```text
allCategories
activeCategories
quickInputCategories
spendingBudgetCategories
fixedSpendingCategories
investmentCategories
categoryById(id)
categoryByName(name)       // legacy bridge for Phase 2.5A
isLoading
errorMessage
reload()
```

Widgets should stop reading `Category.predefined` directly. During Phase 2.5A, financial data still stores category names, so `categoryByName` is a compatibility bridge.

UI loading behavior:

- loading: show compact skeleton or disabled category input
- error: show retry
- empty: repair seed defaults or fallback to `other`

### 12. Legacy category repair

During migration, restore, or explicit repair, scan legacy category names from:

- transactions
- budgets
- budget snapshots
- budget plan items
- recurring transactions
- quick templates

If a legacy category name has no normalized-name match in `categories`, create a placeholder custom category.

Placeholder defaults:

```text
id = legacy_<normalized_slug> if unique, otherwise UUID
name = raw legacy category name
emoji = 📌
kind = spending
budgetBehavior = flexible
quickAmountMin = 10_000
quickAmountDefault = 50_000
quickAmountMax = 5_000_000
voicePhrases = [raw legacy category name]
isSystem = false
isArchived = false
sortOrder = before other
```

Do not create placeholder categories during normal rendering. Placeholder creation belongs in migration/restore/repair paths only.

Rationale: unknown categories such as `Taxi`, `Pet`, or `Quà tặng` should not be silently collapsed into `Khác`. Preserving them prepares clean backfill for Phase 2.6.

### 13. Backup and restore

Backup schema becomes v6 and includes `categories`.

Categories are now persisted user financial configuration, so they belong in full backup.

Old backups v1-v5:

```text
categories missing → seed defaults if category table is empty
```

Seed defaults:

```text
INSERT OR IGNORE by category.id
```

Restore merge:

```text
if category.id missing:
  insert
else if backup.updatedAt > current.updatedAt:
  update current category
else:
  keep current category
```

Restore replace:

```text
clear categories + insert backup categories
if backup has no categories → seed defaults
```

Rationale: category config is mutable user preference. Merge should not blindly overwrite current config, but it should accept a newer backed-up version. Last-write-wins by `updatedAt` is the least surprising merge rule for this app.

### 14. Validation

Category validation is strict.

Rules:

```text
name.trim is not empty
normalizedName is unique
emoji.trim is not empty
quickAmountMin > 0
quickAmountMin <= quickAmountDefault
quickAmountDefault <= quickAmountMax
quickAmountMax <= 999_999_999
voicePhrases has no empty values after trim
kind in [spending, investment]
budgetBehavior in [flexible, fixed, excluded]
```

UI save blocks invalid data with inline errors.

Backup restore rejects invalid category data and fails the whole restore. Do not silently sanitize category data.

Rationale: ADR-0023 already made backup validation strict. Category config affects financial behavior and should be treated with the same discipline.

## Consequences

### Positive

- Category source of truth moves from code to persisted data.
- Future category rename/archive/customization becomes possible.
- Rollover eligibility can derive from behavior instead of hardcoded category lists.
- Backup remains faithful to “full backup = hết”.
- Unknown legacy categories are preserved instead of collapsing into `Khác`.
- Phase 2.6 can backfill `categoryId` deterministically.

### Negative

- Adds a new domain table, datasource, mapper, ViewModel, migration, and backup schema version.
- Phase 2.5A temporarily keeps both persisted categories and legacy category-name references.
- Widgets must handle async category loading.
- Restore merge becomes more complex for category config.

### Deferred

- ~~Category management UI.~~ **Closed by [ADR-0028](../adr/0028-category-management-safe-fields.md)** — safe-fields management UI landed.
- ~~Financial table migration to `categoryId`.~~ **Closed by [ADR-0029](../adr/0029-category-id-financial-table-migration.md)** — `category_id TEXT` added to all financial tables.
- ~~Transaction `categoryNameSnapshot`.~~ **Closed by [ADR-0029](../adr/0029-category-id-financial-table-migration.md)** — `category_name` retained as denormalized snapshot.
- ~~Rollover mode and rollover adjustment traces.~~ **Closed by [ADR-0030](../adr/0030-rollover-category-id-matching.md) + [ADR-0032](../adr/0032-monthly-budget-carry-over.md) + [ADR-0035](../adr/0035-monthly-review-carry-out.md)** — rollover policy and carry-over display landed.
- ~~Advanced editing of `kind` and `budgetBehavior`.~~ **Closed by [ADR-0033](../adr/0033-category-behavior-editing.md)** — `CategoryKind` + `BudgetBehavior` dropdowns in `CategoryEditSheet`.

> All items in this §Deferred list are now closed. Audit 2026-06-13.

## Implementation Notes

Implemented 2026-06-10.

Verification:

- Focused category/backup tests passed: 92/92.
- Full `flutter test` passed: 902/902 after category bridge cleanup.
- `flutter analyze` reports 20 remaining issues, all pre-existing warnings/infos outside the category bridge cleanup.

Implementation notes:

- SQLite DB version is now v12 with `categories` table and indexes.
- `seedCategories` is used only as default seed/test fixture data and fallback when `CategoryLocalDataSource` returns empty (tests, cold-start).
- `CategoryViewModel` is app-level Provider state and feeds low-risk new-entry flows: custom input, quick input, quick add, recurring edit, and transaction edit.
- Backup schema is now v6 and includes `categories`.
- Restore merge uses last-write-wins by `updatedAt` for category conflicts.
- Old backups missing `categories` seed defaults when category table is empty.
- All production code now routes through `CategoryLocalDataSource` / `CategoryViewModel`. `Category.predefined` and `CategoryCompatibilityX` removed from production use.
- ADR-0028 safe-fields management UI added: `Category.validateForEdit()` extension, `CategoryViewModel.updateCategory/resetSystemCategory/toggleArchive` mutations (with budget-aware archive guard), full-screen `CategoryManagementScreen` reachable from the gear menu as "Quản lý danh mục", and `CategoryEditSheet` bottom sheet for editing safe fields (emoji, quick amounts, voice phrases, sort order, archive). Rename/create/hard-delete still deferred.

# ADR-0036: Stats Aggregates by CategoryId

**Date:** 2026-06-13
**Status:** Accepted
**Author:** hiennm11
**Closes:** ADR-0030 §Deferred item 4
**Incidentally closes:** ADR-0031 §Deferred item 5 (`QuickInputWidget._amounts`)

## Context

ADR-0027 introduced persisted `Category.id` as the stable category identity. ADR-0029 added `category_id TEXT` to all financial tables. ADR-0030 then completed rollover apply, live budget mutation, and category archive guards to use `categoryId` for matching. ADR-0031 made category rename and custom category creation possible.

The categoryId migration was intended to flow through every layer that touches category identity. **One site was explicitly deferred** (ADR-0030 §Deferred):

> Moving `ExpenseStats.categoryTotals` from name-keyed maps to categoryId-keyed aggregates.

`ExpenseStats.categoryTotals` is still a `Map<String, int>` keyed by `Transaction.category` (the display-name snapshot, written at transaction creation time and never updated). `MonthlyReviewBuilder` has the same shape in two places (`_buildTopCategories` line 122, `_buildBudgetHighlights` line 328). The deferred item targets the stats type by name but the underlying bug class is "aggregation keyed by mutable display name."

### Concrete consequence today

1. User renames category "Ăn ngoài" → "Đi ăn" (ADR-0031).
2. Future transactions write `categoryId = "cat_eat_out"`, `category = "Đi ăn"`.
3. Old transactions in the same month still carry `category = "Ăn ngoài"`.
4. `categoryTotals` map ends up with **two entries** for the same logical category: `{"Ăn ngoài": 200_000, "Đi ăn": 300_000}`.
5. `chart_widget.dart` `_createSections` draws **two pie slices** for the same category. The legend shows both names. `_computeSpendingTotal` (budget_viewmodel.dart:548) includes both amounts when computing total spending — correct by accident, but the chart is wrong.
6. The same bug occurs in `MonthlyReviewBuilder._buildTopCategories` and `_buildBudgetHighlights`.

Investment exclusion in `BudgetViewModel._computeSpendingTotal` (line 548) still passes `name` to `_isInvestmentCategory` because the map key is a name. After this ADR, the key is an `id` and the lookup uses `Category.kind` via the resolved `Category` object.

## Decision

Migrate every category-aggregation site from name-keyed maps to categoryId-keyed maps. Stats resolve category metadata through the live `CategoryViewModel`/catalog at the widget layer, not at the aggregation layer. One atomic commit touches all 6 source files plus the test fixtures.

### 1. Aggregation key

All three aggregation sites use `Transaction.categoryId` as the map key:

- `ExpenseStats.categoryTotals`: `Map<String, int>` (freezed structure unchanged) — `String` is now `categoryId`, not category name.
- `MonthlyReviewBuilder._buildTopCategories` and `_buildBudgetHighlights` use the same key in their local maps.

```dart
// expense_viewmodel.dart _calculateStats
categoryTotals[transaction.categoryId] =
    (categoryTotals[transaction.categoryId] ?? 0) + transaction.amount;

// monthly_review_builder.dart _buildTopCategories
categoryTotals[tx.categoryId] = (categoryTotals[tx.categoryId] ?? 0) + tx.amount;
```

Defensive: skip a transaction if `categoryId` is empty. v13 migration in `database_helper.dart` already backfills orphan rows with placeholder categories (`placeholder_<norm>_<ms>`), so this should never fire in practice — but a guard costs one line and prevents a `null` key in a `Map<String, int>`.

### 2. Resolution at the UI layer

`ExpenseStats.categoryTotals` and the local maps in `MonthlyReviewBuilder` carry only `(categoryId, amount)` pairs. The widget layer resolves each id to a `Category` for display name, emoji, and color.

```dart
// chart_widget.dart — caller resolves once, widget is stateless
class ChartWidget extends StatelessWidget {
  final Map<String, int> categoryTotals;  // categoryId -> amount
  final List<Category> activeCategories;
  ...
  List<PieChartSectionData> _createSections(...) {
    final colorByCategoryId = {
      for (final c in activeCategories) c.id: colors[c.id.hashCode.abs() % colors.length],
    };
    final nameByCategoryId = {for (final c in activeCategories) c.id: c.name};
    final emojiByCategoryId = {for (final c in activeCategories) c.id: c.emoji};

    return categoryTotals.entries.map((entry) {
      final name = nameByCategoryId[entry.key] ?? 'Khác';
      final emoji = emojiByCategoryId[entry.key] ?? '📌';
      final color = colorByCategoryId[entry.key] ?? AppColors.textSecondary;
      ...
    }).toList();
  }
}
```

Skip a categoryId that is not in the active list. The placeholder-category case still works: placeholders are real rows in `categories` table so they will appear in `activeCategories`; their `name` and `emoji` are seeded during migration, so the user sees a normal slice (e.g. "Khác" with 📌).

`HomeScreen` already watches `CategoryViewModel`; it passes `activeCategories` down to `ChartWidget` via constructor parameter. No new `Consumer`/`Consumer2` needed.

### 3. Investment exclusion

`BudgetViewModel._computeSpendingTotal` and `_calculateStatuses` previously looked up `kind` by name. After the migration they look up by id against the already-loaded `_categories` list:

```dart
// _calculateStatuses (already uses categoryId where it can — finish the job)
final categoryById = {for (final c in _categories) c.id: c};
for (final entry in categoryTotals.entries) {
  final cat = categoryById[entry.key];
  if (cat == null) continue; // orphan, skip
  if (cat.kind == CategoryKind.investment) continue;
  total += entry.value;
}
```

Drop the `name` parameter from `_isInvestmentCategory`. The helper is no longer needed; inline the check on `Category.kind` at the single remaining call site.

### 4. Stable color by categoryId

`chart_widget.dart` `_createSections` and `_Legend` currently color slices by insertion order (`colors[colorIndex % colors.length]`). Same category appearing in two adjacent renames would get different colors. Replace with deterministic id hash:

```dart
final color = colors[entry.key.hashCode.abs() % colors.length];
```

This is a one-line change, but it falls out naturally from the new resolve step. `Category.id` is stable (ADR-0027), so the color is stable.

### 5. Test updates

Update every fixture that constructs `ExpenseStats(...)` or hits the new code path:

- `test/unit/expense_viewmodel_test.dart:312-330` — assert against `categoryId` keys.
- `test/unit/budget_viewmodel_test.dart` — 11 fixtures using `categoryTotals: {'Ăn ngoài': ...}` become `categoryId: 'cat_eat_out'`. Seed `Category` objects with matching ids.
- `test/widgets/budget_overview_widget_test.dart:161-167` — `buildStats` helper switched to categoryId keys.
- `test/unit/monthly_review_builder_test.dart` — assert top-5 sort + budget highlight by id.

Add a focused regression test:

```dart
// test/unit/expense_viewmodel_test.dart
test('categoryTotals aggregates by id across renames', () async {
  // Given: 2 transactions, same categoryId, different category names
  // (one pre-rename, one post-rename)
  // When: stats computed
  // Then: single map entry keyed by categoryId, sum of both amounts
});
```

Mirror for `MonthlyReviewBuilder`:

```dart
// test/unit/monthly_review_builder_test.dart
test('top categories dedupe across rename, investment excluded', () {
  // Given: spending txs with same id different names + 1 investment tx
  // When: build() runs
  // Then: top5 has 1 entry, investment tx absent
});
```

### 6. Incidental closure of ADR-0031 §5

`QuickInputWidget._amounts` was deferred in ADR-0031 §5 ("Fix `quick_input_widget._amounts` to key by `categoryId`"). It is already keyed by `category.id` since the category catalog migration landed (see `quick_input_widget.dart:23, 27, 37, 89, 139`). This ADR records that closure; no code change.

## Considered Options

### A. Keep name-keyed, snapshot at write time

When a category is renamed, walk every existing transaction and update `Transaction.category` to the new name. Cheaper migration, but destroys the historical audit trail (ADR-0029 §"Historical financial rows keep old category name snapshots by design"). Rejected.

### B. categoryId-keyed stats but resolve inline in VM

`ExpenseViewModel` could call `CategoryViewModel.getById` to build a `Map<String, Category>` and stash it on `ExpenseStats`. Saves a parameter on `ChartWidget`. Cost: tightens coupling between `ExpenseViewModel` and `CategoryViewModel`, harder to test stats in isolation, and stats become dependent on VM order of init. Rejected.

### C. categoryId-keyed stats, resolve at widget layer (chosen)

Stats carry only `(id, amount)`. UI widgets that render stats receive a `List<Category>` (or watch `CategoryViewModel`) and resolve metadata there. Keeps `ExpenseStats` data-only, no VM-to-VM coupling, easy to test with plain maps. Matches ADR-0027 vocabulary: id is identity, name/emoji are display attributes owned by `Category`.

### D. Multi-step migration (VM → Monthly Review → UI)

Slice the change: first migrate `ExpenseStats` only, then Monthly Review, then UI. Rejected: the chart would render wrong for one slice between step 1 and step 3. Atomic commit is the only way to keep runtime consistent.

## Consequences

### Positive

- Renaming a category no longer splits its pie slice or top-5 ranking.
- The chart legend and Monthly Review top-5 both reflect the current category display, not a frozen historical name.
- `_computeSpendingTotal` and `_calculateStatuses` are no longer name-lookup-based; they use `Category.id` like every other site.
- Color stability by id hash: same category always gets the same color across rebuilds and across chart/legend/quick-templates.
- Final deferred item from ADR-0030 is closed. ADR-0031 §5 closes incidentally.

### Negative

- Every test fixture that constructed `ExpenseStats` with name keys must be updated. ~12 fixtures across 3 files.
- `ChartWidget` now needs `activeCategories` from the parent. Wiring requires touching `HomeScreen`.
- `_isInvestmentCategory` loses its name fallback. If a future caller holds only a name (e.g. in a search-result context), they must look up the `Category` first. No current caller is in that state.

### Deferred

- None directly from this ADR. ADR-0027's deferred list of "future rollover eligibility" / "rollover adjustment traces" remains open per its original ADR.
- `MonthlyReviewCategorySummary` (`monthly_review_data.dart`) is still keyed by `categoryName` for the display layer. The aggregation step is id-keyed, but the summary model carries `categoryName` for the screen. Renaming a category therefore changes the `categoryName` shown in past months' reviews. This is consistent with ADR-0029's audit-trail intent (summary is a derived display, not persisted) and is **not** part of this ADR.

## Implementation Order

Single commit. Touches:

```
lib/models/expense_stats.dart                                 — doc comment
lib/viewmodels/expense_viewmodel.dart                         — aggregate by id
lib/viewmodels/budget_viewmodel.dart                          — drop name path, id-based kind check
lib/services/monthly_review_builder.dart                      — aggregate by id, use categories param
lib/widgets/chart_widget.dart                                 — accept List<Category>, resolve + stable color
lib/views/home_screen.dart                                    — pass activeCategories to ChartWidget
test/unit/expense_viewmodel_test.dart                         — fixtures + new regression test
test/unit/budget_viewmodel_test.dart                          — fixtures (11 sites)
test/widgets/budget_overview_widget_test.dart                 — buildStats helper
test/unit/monthly_review_builder_test.dart                    — fixtures + new regression test
```

No backup schema bump (stats are derived, not persisted). No DB migration. No `CONTEXT.md` vocabulary additions — terms (`Category.id`, `CategoryKind`, `categoryId`) are already in the glossary.

CONTEXT.md updates:

- §Domain `ExpenseStats` row: add a sentence that `categoryTotals` is `categoryId → amount` and that consumers must resolve via `Category` for display.
- §ADR table: add ADR-0036 row at the appropriate position (after 0035).
- Mark ADR-0030 §Deferred item 4 as resolved in CONTEXT (CONTEXT line 194 already states rollover identity boundary — extend to stats boundary).

## References

- ADR-0027: Persisted Category Catalog
- ADR-0029: CategoryId Financial Table Migration
- ADR-0030: Rollover CategoryId Matching (deferred source)
- ADR-0031: Category Rename and Custom Create (deferred source for §5)
- `lib/viewmodels/expense_viewmodel.dart:518-538`
- `lib/viewmodels/budget_viewmodel.dart:543-599`
- `lib/widgets/chart_widget.dart:30-192`
- `lib/services/monthly_review_builder.dart:122-145, 326-345`
- `lib/models/expense_stats.dart:1-22`

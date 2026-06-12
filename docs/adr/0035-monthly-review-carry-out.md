# ADR-0035: Monthly Review Carry-Out Display

**Date:** 2026-06-12
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0032 added monthly budget carry-over for flexible spending categories. The carry amount is computed and persisted on `BudgetSnapshot.carryAmount`, and `BudgetOverviewWidget` already shows the carry-in line for the current month. 

Monthly Review was explicitly deferred because it required extending the review data model and builder:

```dart
// TODO(ADR-0032 §8): add carryAmount to show "Còn dư chuyển tháng sau"
```

The storage layer is already complete:

- `BudgetSnapshot.carryAmount` field (ADR-0032 §4).
- SQLite v14 `budget_snapshots.carry_amount` column.
- `BudgetSnapshotLocalDataSource.getByYearMonth(yearMonth)` returns rows with carry.
- Backup schema v8 includes `carryAmount`.

Only the presenter layer is missing.

## Decision

Complete the deferred Monthly Review carry-out display.

### 1. Carry data shape

Pass a lightweight carry map from `MonthlyReviewViewModel` into `MonthlyReviewBuilder`:

```text
Map<String, int> carryByCategoryId  // categoryId → carryAmount
```

For past/completed months:
- Load snapshots via `BudgetSnapshotLocalDataSource.getByYearMonth(yearMonth)`.
- Build `carryByCategoryId = {s.categoryId: s.carryAmount for s in snapshots where s.carryAmount > 0}`.

For the current month (in progress):
- Pass an empty map. The current month does not have carry-out because spending is not yet final.

### 2. Model change

Add `carryAmount` to `MonthlyReviewBudgetHighlight`:

```dart
@Default(0) int carryAmount,
```

Regenerate freezed code with `dart run build_runner build --delete-conflicting-outputs`.

### 3. Builder change

Extend `MonthlyReviewBuilder.build()` and `_buildBudgetHighlights()`:

- Accept `Map<String, int> carryByCategoryId` parameter.
- In `_buildBudgetHighlights`, look up `carry = carryByCategoryId[categoryId] ?? 0`.
- Emit `MonthlyReviewBudgetHighlight(carryAmount: carry, ...)`.

### 4. ViewModel change

In `MonthlyReviewViewModel._loadCurrentMonth()`:

- For past months: extract `carryByCategoryId` from loaded snapshots before converting them to `Budget`.
- For current month: `carryByCategoryId = {}`.
- Pass `carryByCategoryId` to `_builder.build(...)`.

### 5. UI rendering

In `MonthlyReviewScreen` (or the widget rendering budget highlights):

- For each highlight row where `carryAmount > 0`:
  ```text
  Còn dư chuyển tháng sau: +300.000 ₫
  ```
- Use green text, small font, below the spent/limit row.

The `MonthlyReviewBudgetHighlight` already has `categoryName` used for display, and the screen already renders budget highlight rows. The carry line is additive.

### 6. Tests

Keep verification focused on this ADR.

Required focused coverage:

```text
monthly_review_builder_test.dart
  → highlights include carryAmount when carry map provided
  → carryAmount defaults to 0 when map empty or missing

monthly_review_viewmodel_test.dart
  → past month carryByCategoryId passed to builder

monthly_review_data_test.dart (or builder test above)
  → MonthlyReviewBudgetHighlight serialization/roundtrip includes carryAmount
```

Run focused only:

```bash
flutter test test/unit/monthly_review_builder_test.dart test/unit/monthly_review_viewmodel_test.dart --no-pub
```

Targeted analyze for changed files.

Do not chase unrelated legacy/full-suite failures.

## Consequences

### Positive

- Monthly Review now fully completes the carry-over story: budget overview shows carry-in, Monthly Review shows carry-out.
- Users can see which categories generated surplus in completed months.
- The last ADR-0032 deferred item is resolved.

### Negative

- `MonthlyReviewBudgetHighlight` model grows one more field, requiring freezed regeneration.
- The builder signature grows one more parameter.

### Deferred

- None. This was the last deferred item from ADR-0032.

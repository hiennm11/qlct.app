# ADR-0040: P1 Test Coverage — Financial Core (2026-06-14)

**Date:** 2026-06-14
**Status:** Accepted
**Author:** hiennm11
**Type:** Contract-ref (no architectural change)

## Context

Sau khi 4-week P0 close (ADR-0030/0032/0035/0037 audit + housekeeping +
UX polish), audit thực tế còn 4 gap test coverage ở financial core:

1. `SqliteBudgetSnapshotDataSource` 6 methods (`getAll`, `getByYearMonth`, `upsert`, `bulkUpsert`, `deleteByYearMonth`, `clearAll`, `count`) chỉ cover gián tiếp qua `MonthlyReviewViewModel` — model + row mapper có dedicated test, datasource không.
2. Private helpers `_computeSuggestion`, `_roundSuggestion`, `_classify`, `_initialPlannedLimit`, `_plannedTotalBudget`, `_formatYearMonth` trong `MonthlyBudgetPlanBuilder` chỉ cover gián tiếp qua integration scenarios.
3. Plan apply edge case khi category trong trash/archived mid-plan — 0 test. Behavior thật (`_isInvestmentCategory` không check `deletedAt` hay `isArchived`) chưa được pin.
4. Snapshot carry khi category bị archive hoặc trash sau khi snapshot tạo — 0 test.

Không bump schema, không touch dependency, không thay đổi version policy → contract-ref.

## Decision

Thêm 4 test groups:

1. `test/unit/sqlite_budget_snapshot_datasource_test.dart` (mới, 17 cases) — cover 6 methods + carryAmount round-trip.
2. `test/unit/monthly_budget_plan_builder_internal_test.dart` (mới, 25 cases) — craft input tối thiểu exercise từng helper qua observable output, không cần `@visibleForTesting` exposure.
3. `test/unit/budget_viewmodel_test.dart` (extend, +3 cases) — pin behavior `_isInvestmentCategory` không filter trash/archived trong plan apply.
4. `test/unit/monthly_review_viewmodel_test.dart` (extend, +3 cases) — pin snapshot carry frozen behavior khi category state thay đổi.

## Consequences

- 48 test cases mới (17 + 25 + 3 + 3). All pass. Toàn bộ 4 gap closed.
- Behavior pin trong gap #3 và #4 trade-off explicit: snapshot/plan apply không filter category state hiện tại — user restore/purge sau này không phá vỡ historical data.
- No production code change. Atomic commits per gap (4 commits, 727244a/ac93140/5183e20/af7826c).

## Verification

```bash
flutter test test/unit/sqlite_budget_snapshot_datasource_test.dart
flutter test test/unit/monthly_budget_plan_builder_internal_test.dart
flutter test test/unit/budget_viewmodel_test.dart
flutter test test/unit/monthly_review_viewmodel_test.dart
flutter analyze test/unit/
```

48/48 cases pass. No analyzer issues.

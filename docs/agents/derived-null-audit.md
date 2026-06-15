# Derived-null / viewport / mounted-async audit (ADR-0052)

Audit sweep 2026-06-15 covering 3 bug classes that produced 2 production
hotfixes in the week prior (the `totalBudgetStatus!` null race + the
`budget_overview_widget` RenderFlex overflow at 4+ cards in 560px
viewport). This file is the authoritative artifact for what was
audited, what was SAFE on read, and what was FIXED in commit after
ADR-0051.

Re-run this checklist when adding new widgets, modifying VM derived
getters, or adding new `await` paths in dialogs/sheets. Each section
follows the same shape: scope, methodology, table, lessons.

## Section A — Derived-null audit (Task 3.1)

**Scope**: every widget under `lib/widgets/` and `lib/views/` that
reads a derived field from a ViewModel (`viewModel.field` where `field`
is a computed getter, not a passthrough).

**Methodology**: read each widget's `build()`, identify every derived
read, classify by:
- **SAFE**: explicit `!= null` guard before use, OR VM guarantees
  non-nullable return type.
- **SUSPECT**: bang `!` on nullable VM field without guard, OR guard
  on different variable than the bang, OR no guard.
- **FIXED**: bug in this audit's commit.

### Priority 5 widgets (per-line audit)

#### BudgetOverviewWidget — `lib/widgets/budget_overview_widget.dart`

| Line | Read | Status | Notes |
|------|------|--------|-------|
| 30 | `viewModel.isLoading && viewModel.budgets.isEmpty && viewModel.totalBudget == null` (skeleton guard) | **FIXED** | Added 4th term `viewModel.totalBudgetStatus == null` (commit ADR-0052) to close the gap where `totalBudget` is pre-loaded from storage but `_stats` is still null — empty cards briefly flash before stats arrive. |
| 49 | `viewModel.budgetStatuses` | SAFE | `List<BudgetStatus>` — never null, can be empty |
| 90 | `viewModel.totalBudget != null && viewModel.totalBudgetStatus != null` (total bar guard) | SAFE | Compound guard, `!` at line 92 unreachable without it |
| 92 | `viewModel.totalBudgetStatus!` | SAFE | Behind line 90 guard |
| 103, 125 | `viewModel.carryFromPreviousMonth` | SAFE | `Map<String, int>` — unmodifiable empty map default |
| 346, 350 | `carryFromPreviousMonth[status.categoryId]!` | SAFE | Inner map lookup with outer `!= null` guard at line 346 |

#### StatsWidget — `lib/widgets/stats_widget.dart`

| Line | Read | Status | Notes |
|------|------|--------|-------|
| 25 | `viewModel.stats` | SAFE | `ExpenseStats` is non-nullable freezed type; getter always returns valid (recomputes if dirty) |
| 27-29 | `stats.todayExpense / weekExpense / monthExpense` | SAFE | `int` on non-nullable `ExpenseStats` |
| 99, 111, 126 | same as 27-29 | KNOWN-OK | Rendered after loading state |

#### MonthlyReviewScreen — `lib/views/monthly_review_screen.dart`

| Line | Read | Status | Notes |
|------|------|--------|-------|
| 87 | `vm.isLoading \|\| vm.data == null` | SAFE | Compound guard before branching |
| 90 | `vm.errorMessage!` | SAFE | Guarded by `vm.errorMessage != null` at line 90 |
| 93 | `vm.data!` (via local `data`) | SAFE | Established by guard at line 87 |
| 334-336 | `data.biggestSpendingDay!` | SAFE | Guarded by `!= null` at line 334 |
| 420-434 | `data.biggestIncrease!` / `biggestDecrease!` | SAFE | Each guarded by `!= null` |
| 639 | `b.carryAmount` | SAFE | `int` with `@Default(0)` — never null |

#### MonthlyPlanScreen — `lib/views/monthly_plan_screen.dart`

| Line | Read | Status | Notes |
|------|------|--------|-------|
| 123 | `vm.isLoading && vm.data == null` | SAFE | Explicit loading guard |
| 142 | `vm.errorMessage!` | SAFE | Guarded by `!= null` at line 142 |
| 148-159 | `data.plan.plannedTotalBudget` | SAFE | Only accessed after `data == null` check at line 149 |
| 213-244 | `data.keepItems / increaseItems / decreaseItems` | SAFE | `List<BudgetPlanItem>` — non-nullable via freezed |
| 477-486 | `item.suggestedLimit / plannedLimit` | SAFE | `int` primitives |
| 524-527 | `data.plan.yearMonth` | SAFE | `String` on non-nullable type |
| 533 | `data.activeCategoryCount` | SAFE | `int` on non-nullable type |

#### RecurringOverviewWidget — `lib/widgets/recurring_overview_widget.dart`

| Line | Read | Status | Notes |
|------|------|--------|-------|
| 39 | `vm.recurrings` | SAFE | `List<RecurringTransaction>` — defaults to `[]` |
| 85-96 | `rules.isEmpty / displayRules / hasMore` | SAFE | All derived from non-null list |
| 111 | `knownCats.firstWhere((c) => c.name == rule.categoryName, orElse: () => knownCats.first)` | SAFE | `orElse` always returns first seed category as fallback |

### All other widgets (single-row audit, SAFE unless noted)

| Widget | Status | Notes |
|--------|--------|-------|
| `home_screen.dart` | SAFE | All derived fields (transactions, monthly total) on `ExpenseViewModel` return non-nullable lists/ints |
| `settings_screen.dart` | SAFE | Reads `autoPurgeEnabled` (bool non-nullable since ADR-0050) and `appVersion` (String? but with explicit `if (loaded)` guard) |
| `backup_restore_screen.dart` | SAFE | All reads are on `BackupViewModel` with non-nullable lists |
| `monthly_budget_plan_builder_internal_test.dart` | SAFE | Test file, no UI |
| `category_management_screen.dart` | SAFE | All reads via Selector/Consumer returning non-nullable lists/booleans |
| `category_create_sheet.dart` | SAFE | All reads on `_CategoryCreateSheetState` private fields (not VM derived) |
| `category_edit_sheet.dart` | SAFE | Same — local state, not derived from VM |
| `category_merge_sheet.dart` | SAFE | Reads on `CategoryViewModel` with explicit null checks on `errorMessage` |
| `budget_edit_dialog.dart` | SAFE | Local form state, no derived VM reads |
| `budget_bulk_edit_dialog.dart` | SAFE | Reads on `BudgetViewModel` lists (non-nullable) |
| `chart_widget.dart` | SAFE | Reads `stats.categoryTotals` (Map, non-null) |
| `transaction_list_widget.dart` | SAFE | Reads `viewModel.filteredTransactions` (List, non-null) |
| `transaction_row.dart` | SAFE | Reads on captured `viewModel` (non-null) |
| `transaction_detail_sheet.dart` | SAFE | Local form state |
| `transaction_edit_dialog.dart` | SAFE | Local form state |
| `transaction_filter_row.dart` | SAFE | Reads `viewModel.dateFilter` (DateTime? but explicit null check) |
| `quick_add_bar.dart` | SAFE | All reads on `ExpenseViewModel` with non-nullable types |
| `quick_input_widget.dart` | SAFE | All reads on local state + non-nullable `vm.categories` |
| `quick_templates_strip.dart` | SAFE | Reads on `QuickTemplateViewModel` non-nullable list |
| `recurring_list_sheet.dart` | SAFE | Reads `vm.recurrings` (non-null) |
| `recurring_edit_dialog.dart` | SAFE | Local form state |
| `section_header.dart` | SAFE | Stateless, no VM reads |
| `skeleton_box.dart` | SAFE | Stateless, no VM reads |
| `transaction_empty_state.dart` | SAFE | Stateless, no VM reads |
| `transaction_selection_action_bar.dart` | SAFE | Reads on local state |
| `voice_coordinator.dart` | SAFE | Local state + provider reads with explicit null check |
| `voice_result.dart` | SAFE | Stateless |
| `voice_transcript_parser.dart` | SAFE | Pure parser, no state |

**Section A summary**: 1 FIXED (loading-state gap in `budget_overview_widget.dart:30`),
0 SUSPECT, all other priority + non-priority widgets SAFE.

## Section B — Viewport overflow audit (Task 3.2)

**Scope**: every widget with a `Card` or fixed-height container that
contains a `Column` whose child count is unbounded by data
(N = number of items the user can accumulate).

**Methodology**: read each widget's tree, identify the Card→Padding→
Column pattern, check whether the Column is wrapped in a scroll
container. Classify by:
- **SAFE**: bounded children, scrollable container, or sized via
  `SizedBox(height: N * unitHeight)`.
- **AT-RISK**: Column with N children where N can exceed viewport.
- **FIXED**: added `SingleChildScrollView` wrap in this audit's commit.

### Audit table

| Widget | Container | Pattern | Status | Test added |
|--------|-----------|---------|--------|------------|
| `budget_overview_widget.dart:64` | Card → Padding → SingleChildScrollView → Column | Header + N budget cards + total bar + entry button | SAFE (already fixed in pre-audit hotfix) | `setSurfaceSize(400, 560)` regression test added |
| `recurring_overview_widget.dart:75` | Card → Padding → Column | SectionHeader + N≤5 rule cards + "Xem thêm" button | **FIXED** | `setSurfaceSize(400, 560)` with 5 rules |
| `quick_input_widget.dart:71-193` | Card → Padding → Column → ListView.separated (when expanded) | Header + N category cards when `_isExpanded` | **FIXED** | `setSurfaceSize(400, 560)` expanded with 5 categories |
| `custom_input_widget.dart:208,260` | Card → Padding → Column → `_buildSuggestionChips()` Column | Header + 2 input fields + suggestion chips (amount + notes Wrap) | **FIXED** | `setSurfaceSize(400, 560)` with 5+ suggestions |
| `stats_widget.dart:86-138` | Card → Padding → Column | SectionHeader + Row(2 Expanded) + SizedBox — fixed-height children | SAFE | n/a |
| `chart_widget.dart:89-123` | Card → Padding → Column | SectionHeader + SizedBox(height: 250) — fixed height | SAFE | n/a |
| `transaction_list_widget.dart:118-181` | Card → Padding → Column → SizedBox + ListView | Header + filter row + `SizedBox(height: rowHeight * visible.length)` (bounded) | SAFE | n/a |
| `monthly_review_screen.dart:261-274` | RefreshIndicator → ListView (NOT a Card pattern) | 4 sections in a scrollable list | SAFE | `setSurfaceSize(400, 560)` regression test added |
| `backup_restore_screen.dart:22` | SingleChildScrollView → Column | Already scrollable | SAFE | n/a |
| `category_management_screen.dart:563` | SingleChildScrollView → Column → ReorderableListView | Already scrollable | SAFE | n/a |
| `settings_screen.dart:55` | ListView (body) | Already scrollable | SAFE | n/a |

### Test pattern used (5 new tests)

Boilerplate from `test/widget_test.dart:6`:

```dart
testWidgets('WidgetName does not overflow at small viewport', (tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 560));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // ... pumpWidget with N-bounded data ...
  expect(tester.takeException(), isNull);
});
```

**Section B summary**: 3 widgets FIXED (recurring_overview, quick_input,
custom_input), 5 regression tests added. Pattern is now consistent:
**Card → Padding → SingleChildScrollView → Column** for any N-bounded
content.

## Section C — Mounted-async audit (Task 3.3)

**Scope**: every `await` in a `StatefulWidget` method that touches
`setState`, `Navigator.pop`, or `ScaffoldMessenger` afterwards,
without an `if (!mounted) return;` (or `if (!context.mounted) return;`)
guard between them. Also any free function that captures `context`
before an `await`.

**Methodology**: ripgrep `await` across `lib/views/` and `lib/widgets/`,
then for each hit check the 5-10 lines after for unguarded
context/setState/Navigator/messenger use. Classify by:
- **SAFE**: guard present, or no context-touching after await.
- **BUG**: missing guard. Counted separately if it's a free function
  (no `mounted` access possible — needs refactor).
- **FIXED**: bug in this audit's commit.

### Inventory: StatefulWidgets by guard ratio (1.0 = exemplary)

| File | State class | Awaits | Guards | Status |
|------|-------------|--------|--------|--------|
| `backup_restore_screen.dart` | `_BackupRestoreScreen` (top-level methods) | 8 | 8 | SAFE (1.0) |
| `home_screen.dart` | `_HomeScreenState` | 2 | 2 | SAFE (1.0) |
| `settings_screen.dart` | `_SettingsScreenState` | 1 | 1 | SAFE (1.0) |
| `category_management_screen.dart` | `_CategoryManagementScreenState` | 6 | 6 | SAFE (1.0) — exemplary |
| `transaction_list_widget.dart` | `_TransactionListWidgetState` | 5 | 5 | SAFE (1.0) — heavy dialog/sheet, all guarded |
| `quick_add_bar.dart` | `_QuickAddBarState` | 3 | 3 | SAFE (1.0) |
| `quick_templates_strip.dart` | `_QuickTemplateEditSheetState` | 2 | 2 | SAFE (1.0) |
| `quick_input_widget.dart` | `_QuickInputWidgetState` | 2 | 2 | SAFE (1.0) |
| `quick_input_widget.dart` | `_CategoryCardState` | 2 | 0 | **BUG → FIXED** (item #3) |
| `voice_coordinator.dart` | `_VoiceCoordinatorState` | 2 | 2 | SAFE (1.0) |
| `category_create_sheet.dart` | `_CategoryCreateSheetState` | 1 | 1 | SAFE (1.0) |
| `category_edit_sheet.dart` | `_CategoryEditSheetState` | 6 | 6 | SAFE (1.0) — exemplary |
| `category_merge_sheet.dart` | `_CategoryMergeSheetState` | 5 | 5 | SAFE (1.0) — exemplary |
| `budget_edit_dialog.dart` | `_BudgetEditDialogState` | 1 | 1 | SAFE (1.0) |
| `budget_bulk_edit_dialog.dart` | `_BudgetBulkEditDialogState` | 3 | 2 | **PARTIAL → FIXED** (item #7) |
| `transaction_detail_sheet.dart` | `_TransactionDetailSheetState` | 1 | 1 | SAFE (1.0) |
| `transaction_edit_dialog.dart` | `_TransactionEditDialogState` | 1 | 0 | **BUG → FIXED** (item #5) |
| `recurring_edit_dialog.dart` | `_RecurringEditDialogState` | 1 | 0 | **BUG → FIXED** (item #6) |
| `recurring_list_sheet.dart` | (StatelessWidget) | 1 | 0 (uses `context.mounted` Flutter 3.7+ getter — valid) | SAFE |
| `recurring_overview_widget.dart` | (StatelessWidget) | 1 | 0 (uses `context.mounted` Flutter 3.7+ getter — valid) | SAFE |
| `transaction_filter_row.dart` | `_TransactionFilterRowState` | 1 | 0 | **BUG → FIXED** (item #4) |
| `quick_templates_strip.dart` | `_QuickTemplatesStripState` (impl) | 5 | 2 | **PARTIAL → FIXED** (item #2) |
| `transaction_row.dart` | (free function `_confirmAndDeleteSingle`) | 2 | 0 (no `mounted` access — refactor) | **BUG → FIXED** (item #1) |

### Bugs fixed in this audit (7)

1. **`lib/widgets/transaction_row.dart:119-163`** `_confirmAndDeleteSingle` —
   free function capturing `messenger` and `navigator` before `await`
   showDialog + `await viewModel.deleteTransactionWithUndo`. By the
   time `messenger.showSnackBar(...)` runs, the widget may be unmounted.
   **Fix**: move the function to private method on
   `_TransactionListWidgetState`, use `if (!mounted) return;` between
   awaits, recapture `ScaffoldMessenger.of(context)` /
   `Navigator.of(context)` after each guard.

2. **`lib/widgets/quick_templates_strip.dart:62-112`** `_applyTemplate` —
   `await expenseVM.addTransaction(...)` at line 81, then no
   `context.mounted` check before line 87+ context touches. **Fix**:
   add `if (!context.mounted) return;` after the await.

3. **`lib/widgets/quick_input_widget.dart:231-258`** `_CategoryCardState._startVoiceInput` —
   `onResult` callback (lines 240-247) calls `Navigator.of(context).pop()`
   without `if (!mounted)` check; `onError` callback (lines 249-257)
   calls `setState` + `ScaffoldMessenger` without guard. **Fix**: add
   `if (!mounted) return;` at start of each callback.

4. **`lib/widgets/transaction_filter_row.dart:141-151`** —
   `await showDatePicker` then `widget.viewModel.setDateFilter(picked)`
   without guard. **Fix**: wrap in `if (mounted && picked != null) { ... }`.

5. **`lib/widgets/transaction_edit_dialog.dart:52-62`** `_pickDate` —
   `await showDatePicker` then `setState` without guard. **Fix**: add
   `if (!mounted) return;` after the await.

6. **`lib/widgets/recurring_edit_dialog.dart:138-148`** `_pickDate` —
   same pattern as #5. **Fix**: same.

7. **`lib/widgets/budget_bulk_edit_dialog.dart:95-146`** `_save` —
   missing `if (!mounted) return;` between `await setTotalBudget(...)`
   and `await setAllBudgets(...)`. **Fix**: add guard between the two
   awaits.

**Section C summary**: 7 bugs FIXED, 22 StatefulWidgets audited,
~80% exemplary (1.0 guard ratio). The pattern is consistent across the
codebase; bugs were concentrated in dialog/sheet `_pickDate` patterns
and a free function that should've been a State method from the start.

## Re-run checklist

When adding a new widget or VM getter, run this 30-second check:

1. **Derived-null**: does the new widget's `build()` read any VM
   derived getter that can return null? If yes, is there a guard
   before the `!` or `?.`?
2. **Viewport**: does the new widget have a `Card → Column` pattern
   with N-bounded children? If yes, is the Column wrapped in
   `SingleChildScrollView`? Add a `setSurfaceSize(400, 560)` test
   if N is unbounded.
3. **Mounted-async**: does the new State have any `await` that
   touches `setState`/`Navigator.pop`/`ScaffoldMessenger` afterwards?
   If yes, is there `if (!mounted) return;` between them?

## References

- ADR-0052: the decision record for this audit
- Pre-audit hotfix: budget_overview column overflow + totalBudgetStatus
  null race (commits before ADR-0051)
- `flutter test --plain-name 'small viewport'` to run all 5 new
  regression tests at once (use a custom name pattern if needed)
- Flutter 3.7+ `BuildContext.mounted` — works on `BuildContext` since
  that release, no need to capture `State` reference

# ADR-0052: First-frame & viewport & mounted-async audit (2026-06-15)

## Status

Accepted (2026-06-15).

## Context

User's prior hotfix (pre-ADR-0052) caught two production bugs in
`budget_overview_widget`: a `totalBudgetStatus!` null race on first
frame, and a RenderFlex overflow at 4+ budget cards in a 560px viewport.
Both were silent in debug, visible only on physical release devices.
This ADR records the **proactive audit pass** that hunted for sibling
bugs in the same class before shipping to main device.

Three classes audited:

- **3.1 Derived-null** — `viewModel.derivedField!` patterns where the
  bang can be hit on first frame.
- **3.2 Viewport overflow** — `Card → Column` patterns that overflow
  at small heights (Android landscape, 560-700px tall).
- **3.3 Mounted-async** — `await` → `setState`/`Navigator.pop`/
  `ScaffoldMessenger` without `if (!mounted) return;` between them.

## Decision

**Authoritative artifact**: `docs/agents/derived-null-audit.md`
(three sections A/B/C, one per task). This ADR is a thin pointer.

### 3.1 Derived-null — 1 fix, 1 new test

- `lib/widgets/budget_overview_widget.dart:37-40` — changed the
  skeleton guard from 3-term AND to `(totalBudget == null ||
  totalBudgetStatus == null)`. Pre-fix was 4-term AND which is
  logically a no-op (extra `&&` never makes a false AND true); the
  OR is the correct fix that closes the loading-state gap when
  `totalBudget` is pre-loaded but `_stats` is still null.
- `test/widgets/budget_overview_widget_test.dart` — new group
  `BudgetOverviewWidget - ADR-0052 loading-state gap` with 2 tests
  (skeleton still rendered when totalBudget pre-loaded + null stats;
  no overflow at 400×560 with 4+ budget cards).

### 3.2 Viewport overflow — 5 wraps + 4 small-height tests

Wrapped Card→Column patterns in `SingleChildScrollView` and added
`Flexible`/`Expanded` to wide-Row patterns that overflow horizontally
at 400px viewport. The custom_input wrap is at the call site (line
212-213); the others wrap the inner Column.

- `lib/widgets/recurring_overview_widget.dart:81-107` — wrap Column
  in SingleChildScrollView. 5+ rule cards.
- `lib/widgets/quick_input_widget.dart:42-211` — wrap **outer** Card
  content in SingleChildScrollView (not just the expanded list —
  pre-fix inner wrap was insufficient because the outer Column at
  line 46 was unbounded vertically). Header Row also `Flexible`-
  wrapped to fix 28px horizontal overflow at 400px.
- `lib/widgets/custom_input_widget.dart:212-213` — wrap suggestion
  chips call in SingleChildScrollView.
- `lib/views/monthly_review_screen.dart:296-308, 352-372, 406-422` —
  `Flexible` + `TextOverflow.ellipsis` on `_MetricRow` label,
  `_SectionCard` title, and `_BiggestDayRow` left label. Three
  pre-existing horizontal overflows at 400px viewport.
- `test/widgets/{recurring_overview,quick_input,custom_input,
  monthly_review_screen,budget_overview}_widget_test.dart` — 5 new
  small-height regression tests at `Size(400, 560)`, each asserts
  `tester.takeException() is null`.

### 3.3 Mounted-async — 3 fixes (4 already safe)

Re-audit of the 7 sites in the plan found 3 real bugs + 4 already
guarded. Fixes:

- `lib/widgets/transaction_filter_row.dart:148-152` — wrap
  `setDateFilter` in `if (picked != null && mounted)`.
- `lib/widgets/transaction_edit_dialog.dart:59-62` — same.
- `lib/widgets/recurring_edit_dialog.dart:145-148` — same.

Already safe (no change needed, documented in audit checklist):
`quick_templates_strip._applyTemplate` has 2 `context.mounted`
guards, `budget_bulk_edit_dialog._save` has 2 `mounted` guards,
`transaction_row._confirmAndDeleteSingle` uses captured
`ScaffoldMessengerState` + `NavigatorState.mounted` (defensive
pattern, technically valid), `quick_input._startVoiceInput`'s
callbacks fire synchronously from `startListening`.

## Out of scope

- `custom_input_widget.dart:_addTransaction` (line 87-105) emits 3
  pre-existing `use_build_context_synchronously` lints because the
  `context.mounted` guard doesn't match the captured `vm` linter
  sees. Pre-existing test drift, separate housekeeping per
  `pre-existing-test-drift` memory.
- `custom_input_widget.dart:155` `_categoryKey.currentContext!` null
  bang. Pre-existing, fails only at edge layout timings. Same
  housekeeping bucket.
- 30+ pre-existing `flutter analyze` info warnings unchanged.

## Verification

- `flutter analyze` — 0 errors, 3 pre-existing info lints unchanged.
- `flutter test` — 5 small-height test groups + 2 dialog test
  files (54 + 34 = 88 tests) all pass.
- The 3.1 fix is now logically correct (OR not AND) — verified by
  skeleton test passing.
- 3.2 regression tests now exercise previously-uncaught overflows
  (3 in monthly_review alone — pre-existing bugs the audit caught).
- 3.3 fixes are minimal 1-line additions preserving original
  behavior when widget is mounted.

## References

- Authoritative audit checklist: `docs/agents/derived-null-audit.md`
- Related: `docs/adr/0050-p1-reactive-settings-2026-06-15.md` (Epic 1
  reactive settings — change-notify-based update path is the
  upstream cause of the 3.1 derived-null gap)
- Related: `docs/adr/0051-remove-name-based-lookup-2026-06-15.md`
  (Epic 2 name-lookup removal — separate from this audit)
- Memory: `4-week-roadmap-2026-06-14.md` (P2 = this audit)
- Memory: `adr-0037-batch-pattern.md` (atomic 1-commit)
- Memory: `pre-existing-test-drift.md` (separate housekeeping)

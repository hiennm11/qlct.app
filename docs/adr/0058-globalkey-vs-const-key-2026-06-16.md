# ADR-0058: GlobalKey must be bound to a widget in the tree (vs const Key test seam)

**Status:** Accepted 2026-06-16
**Type:** Bugfix (GlobalKey binding convention)
**Linked contract:** n/a (no UI behavior change, just restoring the menu open)

## Context

User reports: on free-form (custom) tx input screen, tapping the category dropdown does **not** show the popup — user cannot pick a category.

### Root cause

`lib/widgets/custom_input_widget.dart:22` declared `final _categoryKey = GlobalKey();` and line 155 used `_categoryKey.currentContext!.findRenderObject() as RenderBox` to position `showMenu`.

Line 152 (pre-fix) bound `key: const Key('category-dropdown')` to the `GestureDetector` — the project test-seam convention (ADR-0052/CLAUDE.md: `data-*` HTML ↔ `Key('state-...')` Flutter). The `_categoryKey` GlobalKey was **never assigned to a widget in the tree**, so `currentContext` was always `null` → `!` bang threw on tap → menu never opened.

### How the bug was introduced

Commit `c11ad13` (ADR-0052 audit, 2026-06-15) changed `key: _categoryKey` → `key: const Key('category-dropdown')` to align with the test-seam convention. The `findRenderObject` lookup on line 155 was not updated to match → silent regression.

### Why tests didn't catch it

`test/widgets/custom_input_widget_test.dart` had 3 tests:
- header render check
- "Thêm giao dịch" button check
- 400x560 small-height viewport regression guard (pumps bare Card, no category selected)

None exercised the dropdown tap. The 400x560 test's comment even acknowledged: "the chip path requires a category-selection gesture that has its own pre-existing null-bang bug out of scope for this audit" — that comment became a smell that the dropdown was untested.

## Decision

- **Bind `_categoryKey` to `GestureDetector.key`** (not `const Key(...)`). GlobalKey is for runtime `findRenderObject` / `findAncestor` lookups; const `Key('name')` is for test discovery. They serve different purposes and must not be substituted for each other.
- **Add regression test** that taps the category field and asserts the popup shows a seed category (`Ăn ngoài`). Closes the test gap.

## Self-detection

1. Schema bump? **Không**.
2. Dependency / layer change? **Không**.
3. Release policy / versioning change? **Không**.

→ **Contract-ref ADR** (5-15 dòng), bug fix only.

## Consequences

- 1 line change in `lib/widgets/custom_input_widget.dart`: rebind `GestureDetector.key` to `_categoryKey`.
- New test `category dropdown opens on tap (ADR-0058 regression guard)` in `test/widgets/custom_input_widget_test.dart`.
- Lesson recorded in CONTEXT.md KDD #51.

## See also

- `lib/widgets/custom_input_widget.dart` — fix location
- `test/widgets/custom_input_widget_test.dart` — new test
- `docs/adr/0052-first-frame-viewport-mounted-audit-2026-06-15.md` — introduced the regression in commit c11ad13
- CLAUDE.md — `Key` convention for state, not for render-object lookups

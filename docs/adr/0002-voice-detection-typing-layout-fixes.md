# ADR-0002: Voice Detection, Type Safety & Layout Fixes

**Date:** 2026-06-03
**Status:** Accepted
**Author:** hiennm11

## Context

Prototype-to-Flutter conversion left 4 known bugs that block stability and further development:

1. **QuickVoiceButton** commented out in `home_screen.dart`. Even if uncommented, category detection hardcodes 3 non-existent category names (`'Ăn uống'`, `'Giao thông'`, `'Giáo dục'`) instead of using `Category.phrases`.
2. **DropdownMenuItem layout** — `Row` widget inside `DropdownMenuItem` without width constraint in `custom_input_widget.dart` can overflow on small screens with long category names.
3. **Dynamic typing** — `_TransactionList` uses `final List transactions` (no generic) instead of `final List<Transaction>`, losing compile-time type safety.
4. **Zero unit tests** — only 1 widget smoke test. No coverage for ViewModel, Repository, Services, or Parser.

## Decision

### 1. Category Detection: Use `Category.phrases` for Both Voice Flows

**Problem**: `QuickVoiceButton` hardcodes detection strings (`'ăn'`, `'cơm'`, `'xe'`, `'xăng'`) and maps them to wrong category names. `CustomInputWidget._parseVoiceInput` already does it correctly — iterates `Category.predefined` and matches against `cat.phrases`.

**Decision**: Unify both voice flows to use the same detection algorithm:

```dart
// Both QuickVoiceButton and CustomInputWidget:
for (final cat in viewModel.categories) {
  for (final phrase in cat.phrases) {
    if (lowerTranscript.contains(phrase.toLowerCase())) {
      matchedCategory = cat.name;
      break;
    }
  }
  if (matchedCategory != 'Khác') break;
}
```

- Fallback to `'Khác'` category (emoji `📌`) when no phrase matches.
- Emoji always looked up from the resolved `Category` object — never hardcoded or empty string.
- QuickVoiceButton is uncommented and placed back in HomeScreen layout.

### 2. DropdownMenuItem: Flexible + TextOverflow.ellipsis

**Problem**: `custom_input_widget.dart:195` has `Row(children: [emoji Text, SizedBox, name Text])` inside a `DropdownMenuItem`. Long category names like `"Nhà (Điện, nước, wifi)"` cause overflow on devices with narrow dropdown width.

**Decision**: Wrap the name `Text` widget with `Flexible` + `overflow: TextOverflow.ellipsis`.

```dart
Row(
  children: [
    Text(category.emoji, style: TextStyle(fontSize: 20)),
    SizedBox(width: 8),
    Flexible(child: Text(category.name, overflow: TextOverflow.ellipsis)),
  ],
)
```

- `Flexible` lets the `Text` shrink to available space.
- No `ConstrainedBox` — avoids hardcoding width assumptions.

### 3. `initialValue` → `value` on DropdownButtonFormField

**Problem**: `DropdownButtonFormField` uses deprecated `initialValue` parameter. When voice parsing sets `_selectedCategory` via `setState`, the dropdown UI doesn't rebuild because `initialValue` is evaluated once at widget creation.

**Decision**: Replace `initialValue: _selectedCategory` with `value: _selectedCategory`. The `value` parameter is reactive — dropdown rebuilds when `setState` changes the value.

### 4. Strong Typing: No `dynamic` in Widget Constructors

**Decision**: All collection parameters in widget constructors must use explicit generic types. Specifically:

- `_TransactionList(transactions)` → parameter typed `List<Transaction>`, not `List`.

This is a zero-risk, zero-behavior-change fix that enables compiler type-checking on all member access.

### 5. Test Strategy

**Decision**: Add `mocktail` to `dev_dependencies`. Write unit tests for:

| Module | Priority | Rationale |
|---|---|---|
| `VietnameseNumberParser` | P0 | Voice input depends on correct number extraction. Easy to test (pure function). |
| `ExpenseViewModel` | P0 | All state mutations, filtering, stats calculation. Mock repository + export service. |
| `TransactionRepositoryImpl` | P1 | CRUD correctness, cache behavior. Mock StorageService. |
| `Category.predefined` | P1 | Validate all 11 categories have required fields. Catch accidental model changes. |

Test file structure:
```
test/
├── widget_test.dart                          (existing — smoke test)
└── unit/
    ├── vietnamese_number_parser_test.dart    (new)
    ├── expense_viewmodel_test.dart           (new)
    ├── transaction_repository_impl_test.dart (new)
    └── category_test.dart                    (new)
```

**Not covered yet**: Integration tests, widget tests for individual widgets, ExportService tests — deferred to follow-up ADR.

## Consequences

### Positive
- Voice input works across **all 11 categories**, not just 3 (wrong) ones.
- No layout overflow on small screens for category dropdown.
- Compiler catches type errors at build time instead of runtime crashes.
- Unit tests provide safety net for future refactors.

### Negative
- Voice detection is still exact substring matching — "ăn" in "ăn ngoài" will match before "ăn nhà" due to iteration order. Phrase priority order in `Category.predefined` matters.
- QuickVoiceButton as inline FAB in scrollable column is suboptimal UX (should be `Scaffold.floatingActionButton`). Deferred to design review.
- `VietnameseNumberParser` has known bugs with multi-unit numbers (e.g. "một trăm hai mươi" → 1020 instead of 120). Not fixed here — test will document the bug.

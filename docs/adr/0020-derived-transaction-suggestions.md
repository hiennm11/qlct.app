# ADR-0020: Derived Transaction Suggestions

**Date:** 2026-06-07
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0019 added **Quick Templates** as user-managed preset transactions. Templates reduce friction for known repeat behaviors, but there is still a lighter use case: when user chooses a category, the app can suggest likely amounts and notes from recent transaction history.

The current architecture is DataSource-first after ADR-0018. `ExpenseViewModel` already memoizes transactions and stats after ADR-0017, and transaction history is already loaded in-memory as a recent paginated window.

Adding a persisted suggestion table would create avoidable schema, migration, backup and restore work. Suggestions are not user-authored records. They are derived from existing transactions.

## Decision

Add transaction suggestions as **derived data**, not persisted data.

Create a pure suggestion engine:

```text
lib/services/transaction_suggestion_engine.dart
```

MVP API:

```dart
class TransactionSuggestionEngine {
  List<int> getSuggestedAmounts(
    Category category,
    List<Transaction> recentTransactions,
  );

  List<String> getSuggestedNotes(
    Category category,
    List<Transaction> recentTransactions,
  );
}
```

The engine must be stateless and deterministic:

- no `DataSource` dependency
- no SQLite query
- no `ChangeNotifier`
- no cache
- no side effect
- easy unit tests

UI passes `ExpenseViewModel.allTransactions` into the engine. This is the currently loaded recent paginated window, not full transaction history.

## Amount Rules

Only transactions with the selected category are considered.

Output constraints:

- max 3 amount suggestions
- unique values
- ignore amount `<= 0`
- preserve priority order

### Subscription

For category `Subscription`:

1. exact last used amount
2. top repeated amounts

Rationale: subscription charges are usually stable. Last exact value is more useful than median.

### Ăn ngoài / Cà phê

For categories `Ăn ngoài` and `Cà phê`:

1. median of recent amounts
2. top repeated amounts
3. last used amount if still fewer than 3 suggestions

Rationale: food and coffee vary slightly; median avoids overreacting to one unusual transaction.

### Other categories

For all other categories:

1. last used amount
2. top repeated amounts

## Note Rules

Only transactions with the selected category are considered.

Output constraints:

- max 3 note suggestions
- trim whitespace
- ignore empty notes
- case-insensitive duplicate detection
- display the most recent casing/text version

Priority:

1. most recent non-empty note
2. most repeated notes

Rationale: notes usually capture current habit/context. Recent note is more useful than globally frequent note, but repeated notes still provide fallback suggestions.

## UI

Initial MVP surfaces suggestion chips in two places.

### CustomInputWidget

When user selects a category:

```text
Amount field
Category picker
[50.000] [35.000] [25.000]
Note field
[cf sáng] [cơm trưa] [...]
```

Behavior:

- tap amount chip → autofill amount field
- tap note chip → autofill note field
- no auto-submit
- chips update when category changes

### QuickTemplateEditSheet

When user creates or edits a template:

- show amount chips after category selection
- show note chips after category selection
- tap chip overrides current field value

Rationale: template creation benefits from existing transaction history without auto-generating templates.

## Data Source

MVP uses only:

```dart
ExpenseViewModel.allTransactions
```

Do not add:

- `suggestions` table
- `SuggestionLocalDataSource`
- `TransactionLocalDataSource.getRecentByCategory(...)`
- full-history load for suggestions

Tradeoff: suggestions only see the currently loaded recent window, initially 50 transactions. This is acceptable because suggestions should prefer recent behavior and keeps ADR-0017 pagination intact.

If later evidence shows the recent window is too small, add a targeted query as a separate ADR/slice:

```dart
TransactionLocalDataSource.getRecentByCategory(String category, int limit)
```

## Template Suggestions

`getSuggestedTemplates(...)` is out of scope for MVP.

Reason:

- `QuickTemplatesStrip` already shows pinned/frequent/recent templates.
- Showing template suggestions inside `CustomInputWidget` duplicates the strip.
- `QuickTemplateEditSheet` mainly needs amount/note autofill, not template-to-template suggestions.

Template suggestion can be revisited later if category-specific template discovery becomes necessary.

## Follow-up Expansion

After MVP verification on device, suggestions were expanded to additional form-fill surfaces while keeping the same derived-data rule.

Additional placements:

- `RecurringEditDialog`: amount + note chips for selected category. Useful for subscriptions and fixed monthly expenses.
- `TransactionEditDialog`: amount + note chips for selected category. Current transaction is filtered out before calling the engine, so it does not suggest its own existing amount/note.
- `QuickInputWidget`: compact amount-only chips on each category card. No note chips because the quick-add path has no note field except voice.

All follow-up placements still use:

```dart
ExpenseViewModel.allTransactions
```

No database, DataSource, migration, full-history query, template suggestions, or auto-submit behavior were added.

## Tests

### Unit tests

Add tests for `TransactionSuggestionEngine`:

- empty transactions → no suggestions
- ignores transactions from other categories
- top repeated amounts by category
- `Subscription` uses last amount first
- `Ăn ngoài` / `Cà phê` use median first
- duplicate amount suggestions are removed
- note suggestions use recent note first
- note duplicates are counted case-insensitively
- note suggestions display most recent text version
- max 3 suggestions

### Widget tests

Add focused widget tests where feasible:

- selecting category in `CustomInputWidget` shows suggestion chips
- tapping amount chip fills amount field
- tapping note chip fills note field
- `QuickTemplateEditSheet` chip tap overrides amount/note

## Acceptance Criteria

- No new database table or migration.
- No new DataSource for suggestions.
- Suggestion engine is pure and stateless.
- Suggestions derive from `ExpenseViewModel.allTransactions`.
- Amount chips follow category-specific rules.
- Note chips follow recent-then-repeated rule.
- Chips autofill fields only; they do not auto-submit.
- `CustomInputWidget` shows suggestions after category selection.
- `QuickTemplateEditSheet` shows suggestions after category selection.
- `RecurringEditDialog` and `TransactionEditDialog` show amount/note suggestions when an `ExpenseViewModel` is available.
- `QuickInputWidget` shows compact amount-only suggestions per category card.
- Template suggestions remain out of scope for MVP.

## Consequences

### Positive

- Improves entry speed without new persistence complexity.
- Preserves DataSource-first architecture.
- Avoids DB migration and backup schema changes.
- Easy to test with pure inputs/outputs.
- Keeps suggestions aligned with recent user behavior.

### Negative

- Suggestions only use loaded recent transactions, not full history.
- Pure rule engine may miss merchant-specific patterns.
- UI must pass transaction history into widgets that need suggestions.

### Risks

- Stale or weak suggestions if user has not loaded enough history.
- Too many chips can clutter forms; MVP limits to max 3 amounts and 3 notes.
- Median rule for food/coffee may feel odd for users who expect last value; tests and UX should make priority explicit.

## Out of Scope

- Persisted suggestion memory.
- Merchant/fuzzy matching.
- Auto-template generation.
- Template suggestions.
- Full-history suggestion queries.
- ML or ranking model.

## References

- ADR-0017: Performance Sanity
- ADR-0018: Remove Pass-through Repositories
- ADR-0019: Quick Templates
- `CONTEXT.md`

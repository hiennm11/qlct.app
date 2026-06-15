# ADR-0051: Remove name-based category lookup

- Status: Accepted
- Date: 2026-06-15
- Build: 1.7.0+20260615xx (RC bump on BUILD; no schema/dependency change)
- Closes: ADR-0030 §Negative (final state), CONTEXT.md §Closed "Hard removal target next release"
- Related: [ADR-0029](../adr/0029-category-id-financial-table-migration.md), [ADR-0030](../adr/0030-rollover-category-id-matching.md)

## Context

ADR-0029 (2026-06-10) established `categoryId` as the financial identity
boundary and kept `categoryName` columns as denormalized display snapshots.
ADR-0030 (2026-06-12) added `BudgetLocalDataSource.getByCategoryId(String)`
as the canonical lookup seam, and on 2026-06-14 (Tuần 1 P0 audit) soft-
deprecated `BudgetLocalDataSource.getByCategory(String categoryName)` and
`TransactionLocalDataSource.getByCategory(String category)` with
`@Deprecated` annotations pointing to the replacements. Since then:

- Zero production callers in `lib/` (verified by grep; doc note in
  `budget_local_datasource.dart:7-10` + `transaction_local_datasource.dart:11-14`,
  also in ADR-0030 §Negative resolution 2026-06-14).
- Transaction replacement is **in-memory filter on `Transaction.category`
  snapshot** (ADR-0029 §Decision item 2 + `TransactionSuggestionEngine`
  pattern), not an id-keyed datasource method — there is no
  `getByCategoryId` on `TransactionLocalDataSource` by design.
- Budget replacement is `getByCategoryId`, used in 7 production sites
  (`BudgetViewModel.setBudget/deleteBudget/setAllBudgets`,
  `CategoryViewModel.toggleArchive/createCustomCategory/deleteCategory`).

The "next release" hedge in ADR-0030 §Negative and CONTEXT.md:222 is
overdue. This ADR hard-removes the deprecated surface.

## Decision

Delete the deprecated methods, their docstrings, and every test/fake/
mock site that still holds the old interface.

### Lib deletions (4 sites)

- `lib/data/datasources/budget_local_datasource.dart:7-11` — abstract
  `getByCategory(String)` + 4-line docstring + `@Deprecated`. Replaced
  with a 2-line docstring on `getByCategoryId` referencing ADR-0030 +
  ADR-0051.
- `lib/data/datasources/transaction_local_datasource.dart:11-16` —
  abstract `getByCategory(String)` + 4-line docstring + `@Deprecated`.
- `lib/data/datasources/sqlite_budget_datasource.dart:53-65` — concrete
  SQL impl (`WHERE category_name = ?`).
- `lib/data/datasources/sqlite_transaction_datasource.dart:94-105` —
  concrete SQL impl (`WHERE category = ?`).

### Test surgery (5 sites)

- `test/unit/sqlite_budget_datasource_test.dart:309-335` — delete
  `group('getByCategory', ...)` (2 tests). `group('getByCategoryId')`
  at line 337 covers the same semantic via id.
- `test/unit/sqlite_transaction_datasource_test.dart:190-219` — delete
  `group('getByCategory', ...)` (1 test) and **add new test**
  asserting the in-memory filter contract: 2 transactions inserted
  with different `category` snapshots, `getAll().where((t) =>
  t.category == 'Ăn ngoài').toList()` returns the 1 matching row.
  Pattern matches `TransactionSuggestionEngine` (ADR-0029).
- `test/widgets/budget_overview_widget_test.dart:78` — delete the
  mocktail `when(() => mockRepo.getByCategory(any()))` stub. Other
  8 stubs on the same mock stay.
- `test/unit/category_viewmodel_mutation_test.dart:181-188` — delete
  `getByCategory` override in `_FakeBudgetDataSource`. `getByCategoryId`
  override (line 191) stays.
- `test/widgets/transaction_list_widget_test.dart:54-55` — delete
  `getByCategory` stub in `_FakeTransactionDataSource`.

Net test count: -2 (3 deleted, 1 added).

## Consequences

### Positive

- API surface back to a single canonical lookup per concern: id-based
  for budget, in-memory snapshot filter for transaction (matches
  `TransactionSuggestionEngine` pattern).
- Dart analyzer no longer flags any fake override for missing the
  deprecated method, and `flutter analyze` warnings about
  `deprecated_member_use` in the test file cannot recur.
- Future contributors cannot accidentally reach for the name-based
  method — there is no longer a method to reach for.
- ADR-0030 §Negative can finally resolve from "next release" hedge to
  a closed entry.

### Negative

- None observable. Every replacement is already exercised in production
  (7 id-based budget call sites; transaction filter used by
  `ExpenseViewModel` + `TransactionSuggestionEngine`) and in tests
  (id-based budget group, suggestion engine tests, and the new
  in-memory filter test added by this ADR).

## Out of scope

- `Transaction.category` snapshot column stays as-is (denormalized
  display per ADR-0029 §Decision item 2). Removing it would touch
  schema, backup format, and all read/display paths.
- `Budget.categoryName` and `RecurringTransaction.categoryName` columns
  stay as snapshots (same rationale).
- `CategoryViewModel.categoryByName` (mentioned in ADR-0029 §Decision
  item 10) does not exist in code — was a hypothetical future bridge,
  not a real method. No-op edit.

## Verification

- `flutter analyze`: 0 errors, 0 new warnings.
- `flutter test`: all existing tests pass + 1 new in-memory filter
  test.
- `grep -rn "getByCategory\b" lib/ test/`: returns only `getByCategoryId`
  matches and `group('getByCategoryId', ...)` test labels.
- `grep -rn "@Deprecated" lib/data/datasources/`: 0 occurrences (was 2).
- Atomic 1-commit per `adr-0037-batch-pattern` memory: code + tests +
  this ADR + ADR-0030 update + CONTEXT.md update + `pubspec.yaml` RC
  bump on BUILD.

## References

- ADR-0029 §Decision item 2: snapshot column rationale.
- ADR-0029 §Decision item 10: hypothetical `categoryByName` bridge
  (this ADR makes it moot by removing the upstream datasource seam).
- ADR-0030 §Decision item 3: `getByCategoryId` introduction.
- ADR-0030 §Negative resolution (line 142): previous "soft-deprecated,
  hard removal next release" state, now closed by this ADR.
- CONTEXT.md §Key Design Decisions #35: id-based rollover identity.
- CONTEXT.md §Open Deferred Items → §Closed by Tuần 1 P0 audit
  (2026-06-14): previous closure entry referencing "next release".

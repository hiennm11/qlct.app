# ADR-0018: Remove Pass-through Repositories

**Date:** 2026-06-07
**Status:** Accepted
**Author:** hiennm11
**Revisits:** ADR-0004 (SQLite + UUID + DataSource), ADR-0017 (Performance Sanity)

## Context

Current data path is:

```text
ViewModel / BackupService
  → Repository interface
  → RepositoryImpl
  → LocalDataSource interface
  → SqliteDataSource
  → SQLite
```

The Repository layer stayed shallow:

- `TransactionRepositoryImpl` only forwards every method to `TransactionLocalDataSource`.
- `BudgetRepositoryImpl` only forwards every method to `BudgetLocalDataSource`.
- `RecurringRepositoryImpl` only forwards every method to `RecurringLocalDataSource`.

The Repository Interface is nearly as complex as the Implementation. It gives no current leverage: no validation, no caching, no transaction orchestration, no domain rule, no cross-table behavior.

The real Implementation lives in the DataSource modules:

- `SqliteTransactionDataSource` owns query filtering, pagination, search, dedup query, insert/update/delete.
- `SqliteBudgetDataSource` owns budget persistence.
- `SqliteRecurringDataSource` owns recurring rule persistence.

The existing tests already prove DataSource behavior directly through SQLite tests. Repository tests only prove pass-through wiring.

Apply the deletion test:

- Deleting Repository complexity does not push meaningful behavior into callers.
- It removes a pass-through Module.
- The real seam remains the LocalDataSource Interface.

## Decision

Remove the Repository layer.

ViewModels and BackupService depend on the abstract DataSource Interfaces directly:

```text
ExpenseViewModel
  → TransactionLocalDataSource

BudgetViewModel
  → BudgetLocalDataSource

RecurringTransactionViewModel
  → RecurringLocalDataSource
  → TransactionLocalDataSource

BackupService
  → TransactionLocalDataSource
  → BudgetLocalDataSource
  → RecurringLocalDataSource
  → DatabaseHelper
```

Keep these DataSource Interfaces as the seam:

- `TransactionLocalDataSource`
- `BudgetLocalDataSource`
- `RecurringLocalDataSource`

The current concrete Adapters remain:

- `SqliteTransactionDataSource`
- `SqliteBudgetDataSource`
- `SqliteRecurringDataSource`

Rationale:

- One adapter means the seam is still hypothetical for runtime storage switching.
- But the seam is real enough for tests: ViewModel tests can mock/fake the DataSource Interface.
- Removing Repository removes a shallow Module while keeping testability.

## Consequences

### Positive

- Fewer shallow Modules.
- Less call-chain noise when tracing data behavior.
- DataSource becomes the explicit persistence seam.
- Repository Impl tests can be deleted because they only verify delegation.
- `main.dart` DI wiring becomes simpler.
- Future remote sync can still add a second Adapter behind the same DataSource Interface.

### Negative

- Many ViewModel/widget/service tests must rename mocks:
  - `MockTransactionRepository` → `MockTransactionLocalDataSource`
  - `MockBudgetRepository` → `MockBudgetLocalDataSource`
  - `MockRecurringRepository` → `MockRecurringLocalDataSource`
- `BackupService` constructor changes.
- `RecurringTransactionViewModel` continues to need two DataSource Interfaces because recurring generation writes Transactions. That cross-domain flow remains explicit.
- ADR-0004's Repository mention is superseded for the current app shape.

### Not decided here

- Do not add remote sync now.
- Do not add in-memory DataSource Adapters now unless tests need them.
- Do not move SQLite row mappers into models. Data-layer mappers are handled separately.
- Do not split ViewModels as part of this ADR.

## Implementation Order

1. Update constructor dependencies:
   - `ExpenseViewModel`: `TransactionRepository` → `TransactionLocalDataSource`
   - `BudgetViewModel`: `BudgetRepository` → `BudgetLocalDataSource`
   - `RecurringTransactionViewModel`: `RecurringRepository` + `TransactionRepository` → `RecurringLocalDataSource` + `TransactionLocalDataSource`
   - `BackupService`: 3 Repository deps → 3 DataSource deps

2. Update `main.dart` wiring:
   - instantiate SQLite DataSources directly
   - remove RepositoryImpl construction
   - pass DataSource Interfaces into ViewModels and BackupService

3. Update tests:
   - replace Repository mocks/fakes with DataSource mocks/fakes
   - update integration tests to bypass RepositoryImpl
   - delete RepositoryImpl tests

4. Delete Repository files:
   - `lib/repositories/transaction_repository.dart`
   - `lib/repositories/transaction_repository_impl.dart`
   - `lib/repositories/budget_repository.dart`
   - `lib/repositories/budget_repository_impl.dart`
   - `lib/repositories/recurring_repository.dart`
   - `lib/repositories/recurring_repository_impl.dart`

5. Run:

```bash
flutter test
```

## References

- ADR-0004: SQLite + UUID + DataSource
- ADR-0017: Performance Sanity
- `lib/repositories/*`
- `lib/data/datasources/*`
- `lib/viewmodels/*`
- `lib/services/backup_service.dart`
- `lib/main.dart`

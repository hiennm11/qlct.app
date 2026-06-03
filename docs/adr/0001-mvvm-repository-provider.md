# ADR-0001: MVVM + Repository with Provider

**Date:** 2026-06-02
**Status:** Accepted
**Author:** hiennm11

## Context

Building a Flutter personal expense tracker (qlct.app) converted from an HTML/JS SPA prototype. Need to decide on architecture pattern, state management, and data persistence.

## Decision

### Architecture: MVVM + Repository

- **Single ViewModel** (`ExpenseViewModel`) — manages all app state (transactions, filters, stats). App is small enough (1 screen, CRUD operations) that splitting into feature VMs adds unnecessary complexity.
- **Repository pattern** — `TransactionRepository` (abstract interface) + `TransactionRepositoryImpl` (SharedPreferences-backed). ViewModel never touches storage directly.
- **Freezed models** — `Transaction`, `Category`, `ExpenseStats` are immutable Freezed classes with JSON serialization via `json_serializable`.

### State Management: Provider + ChangeNotifier

- `ExpenseViewModel extends ChangeNotifier` — notifies `Consumer` widgets on state changes.
- Wired via `ChangeNotifierProvider` in `main.dart`.
- Widgets use `context.read<T>()` for actions, `Consumer<T>` for reactive rebuilds.

### Storage: SharedPreferences (JSON)

- `StorageService` wraps `SharedPreferences` with typed `saveList`/`loadList` methods.
- Transactions stored as JSON-encoded list under key `"transactions"`.
- In-memory cache (`_cachedTransactions`) in repository to avoid re-parsing on every read.

### No DI Framework

- Manual constructor injection in `main()`. Chain: `SharedPreferences → StorageService → TransactionRepositoryImpl → ExpenseViewModel → MyApp`.
- Rationale: 5 dependencies total. DI framework overkill.

## Consequences

### Positive
- Simple, readable DI chain. No magic.
- Repository interface enables swapping storage backend (e.g. SQLite, API) without touching ViewModel/Widgets.
- Freezed ensures immutability — no accidental mutation bugs.

### Negative
- Single ViewModel will grow large if more features added (budgets, recurring transactions, sync). Will need refactor to multi-VM.
- SharedPreferences is synchronous-blocking on read. Large transaction lists (>10k) may cause UI jank. SQLite recommended for scale.
- No test coverage on ViewModel, Repository, or Services.

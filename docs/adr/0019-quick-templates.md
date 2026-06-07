# ADR-0019: Quick Templates

**Date:** 2026-06-07
**Status:** Accepted
**Author:** hiennm11

## Context

`qlct.app` đã có nền nhập liệu nhanh: `QuickAddBar` gộp voice input, quick category grid và custom input. App cũng đã có recurring transactions, budget, search, stats, chart, backup/restore và transaction detail/edit.

Nhưng quick input hiện vẫn xoay quanh **category**, chưa phản ánh hành vi thật hằng ngày như:

- `Cơm trưa 35k`
- `Cà phê sáng 25k`
- `Shopee 120k`
- `Copilot tháng`

Những hành vi này là **preset giao dịch cụ thể**, không chỉ là category. Mục tiêu của feature này là giảm friction nhập liệu hằng ngày hơn nữa: user bấm 1 lần để ghi giao dịch hay dùng.

Theo ADR-0018, Repository layer đã bị xoá. Persistence seam hiện tại là DataSource interface. Vì vậy Quick Templates phải là domain hạng nhất theo pattern hiện tại: immutable model, mapper, datasource interface, SQLite implementation, ViewModel riêng.

## Decision

Thêm domain **QuickTemplate**.

Data flow:

```text
QuickTemplatesStrip / ManageTemplatesSheet / TransactionDetailSheet
  → QuickTemplateViewModel
  → QuickTemplateLocalDataSource
  → SqliteQuickTemplateDataSource
  → SQLite
```

`ExpenseViewModel` không quản lý template CRUD. `ExpenseViewModel` chỉ tiếp tục quản lý transaction. Khi user tap template, UI layer điều phối:

```text
User tap template
  → UI tạo Transaction từ QuickTemplate
  → ExpenseViewModel.addTransaction()
  → nếu success: QuickTemplateViewModel.markUsed(template.id)
  → nếu fail: không tăng usageCount
```

Rationale: template là shortcut để tạo transaction, nhưng không thuộc transaction aggregate. Giữ `ExpenseViewModel` gọn, tránh god object.

## Model

Tạo `QuickTemplate` immutable model bằng Freezed:

```dart
QuickTemplate(
  id: String,
  title: String,
  amount: int,
  categoryName: String,
  note: String,
  emoji: String,
  isPinned: bool,
  usageCount: int,
  lastUsedAt: DateTime?,
  createdAt: DateTime,
  updatedAt: DateTime,
)
```

Không thêm `mode instant/editable` trong MVP. Quyết định UX cho MVP:

- Tap template = add transaction ngay.
- Long press / edit menu = sửa template.
- Nếu cần “sửa trước khi add” sẽ làm sau bằng flow riêng, không thêm vào model v1.

## SQLite

Bump database version **v7 → v8**.

Tạo bảng riêng, không lưu trong SharedPreferences/settings.

```sql
CREATE TABLE quick_templates (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  amount INTEGER NOT NULL,
  category_name TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  emoji TEXT NOT NULL,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  usage_count INTEGER NOT NULL DEFAULT 0,
  last_used_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

Indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_quick_templates_pinned
ON quick_templates(is_pinned);

CREATE INDEX IF NOT EXISTS idx_quick_templates_usage
ON quick_templates(usage_count DESC, last_used_at DESC);
```

Default sort:

```text
isPinned DESC
usageCount DESC
lastUsedAt DESC NULLS LAST
createdAt DESC
```

Không thêm unique index duplicate trong DB ở MVP. Exact duplicate được chặn ở ViewModel/DataSource layer để tránh scope migration phức tạp.

## DataSource

Tạo:

```text
lib/data/datasources/quick_template_local_datasource.dart
lib/data/datasources/sqlite_quick_template_datasource.dart
lib/data/mappers/quick_template_mapper.dart
```

Interface tối thiểu:

```dart
abstract class QuickTemplateLocalDataSource {
  Future<List<QuickTemplate>> getAll();
  Future<List<QuickTemplate>> getTopTemplates({int limit = 8});
  Future<QuickTemplate?> getById(String id);
  Future<bool> existsExactDuplicate({
    required String title,
    required int amount,
    required String categoryName,
    required String note,
    String? excludeId,
  });
  Future<void> insert(QuickTemplate template);
  Future<void> update(QuickTemplate template);
  Future<void> delete(String id);
  Future<void> markUsed(String id, DateTime usedAt);
  Future<void> insertMany(List<QuickTemplate> templates);
  Future<void> clearAll();
}
```

`markUsed` increments `usage_count` and sets `last_used_at` in SQL.

## ViewModel

Tạo `QuickTemplateViewModel`.

Responsibilities:

- load templates
- expose sorted list for strip/manage UI
- create template
- update template
- delete template
- pin/unpin template
- mark used after successful transaction add
- exact duplicate validation
- loading/error state

Không tạo transaction trong `QuickTemplateViewModel`.

## UI

### HomeScreen placement

Thêm `QuickTemplatesStrip` ngay dưới `QuickAddBar`:

```text
QuickAddBar
QuickTemplatesStrip
BudgetOverviewWidget
TransactionListWidget
StatsWidget + ChartWidget
RecurringOverviewWidget
```

### QuickTemplatesStrip

Hiển thị tối đa **8 templates**:

1. pinned trước
2. nếu chưa đủ 8 thì auto-fill bằng frequent/recent
3. sort theo `usageCount DESC`, `lastUsedAt DESC`, `createdAt DESC`

UX:

- Tap chip/card = add transaction ngay.
- Nếu add success → snackbar success + `markUsed`.
- Nếu add fail → snackbar error, không `markUsed`.
- Horizontal scroll trên mobile.
- Empty state compact: `+ Tạo mẫu nhanh`.

Rationale: pinned cho user control, frequent/recent giúp feature hữu ích ngay cả khi user chưa pin gì.

### ManageTemplatesSheet

Bottom sheet để quản lý templates:

- create
- edit
- delete
- pin/unpin

Delete behavior:

```text
Tap delete
  → confirm dialog "Xoá mẫu này?"
  → delete
  → snackbar "Đã xoá mẫu"
```

Không có undo cho template delete trong MVP. Confirm là đủ.

Validation:

- `title.trim().isNotEmpty`
- `amount > 0`
- `categoryName` phải là category hợp lệ trong edit/create sheet

### Create from transaction

Thêm action `Lưu làm mẫu` trong `TransactionDetailSheet`.

Mapping:

```text
title = transaction.note.trim() nếu có, fallback transaction.category/categoryName
amount = transaction.amount
categoryName = transaction.category/categoryName
note = transaction.note
emoji = transaction.emoji
isPinned = false
usageCount = 0
lastUsedAt = null
createdAt = now
updatedAt = now
```

Không mở sheet khi lưu từ transaction. User có thể sửa sau trong `ManageTemplatesSheet`.

### Recurring rule → template

Không nằm trong MVP.

Reason: recurring đã là automation. Biến recurring rule ngược lại thành manual template không phải critical path cho Step 1.

## Duplicate rule

Khi tạo template, chặn exact duplicate.

Duplicate key:

```text
title.trim().toLowerCase()
amount
categoryName
note.trim().toLowerCase()
```

Nếu trùng:

```text
Không insert
Snackbar: "Mẫu này đã tồn tại"
```

Cho phép các template khác title nhưng cùng amount/category/note, vì user có thể muốn đặt tên khác cho ngữ cảnh khác.

## Backup / Restore

QuickTemplate là user-generated data nên phải nằm trong backup/restore ngay MVP.

Bump backup schema **v1 → v2**.

`BackupData` thêm:

```dart
quickTemplates: List<QuickTemplate>
```

Compatibility:

- Backup v1 thiếu `quickTemplates` → default `[]`.
- Backup v2 có `quickTemplates` → restore bình thường.

Restore behavior:

- merge: `INSERT OR IGNORE` templates.
- replace: clear `quick_templates` + insert templates trong cùng DB transaction.

`BackupService` tiếp tục dùng DataSource interfaces trực tiếp theo ADR-0018.

## Category validation and restore tolerance

Trong create/edit UI, user phải chọn category hợp lệ từ `Category.predefined`.

Khi restore backup từ file cũ/lạ, không drop template chỉ vì category không còn trong predefined list. Preserve raw template data để tránh mất dữ liệu.

Khi add transaction từ template có category lạ:

- fallback category về `Khác` nếu tồn tại
- fallback emoji về template emoji hoặc `📌`

Rationale: restore phải khoan dung; UI edit phải sạch.

## Implementation Order

### Slice 1 — Data foundation

1. `lib/models/quick_template.dart`
2. Freezed/json codegen
3. `lib/data/mappers/quick_template_mapper.dart`
4. `QuickTemplateLocalDataSource`
5. `SqliteQuickTemplateDataSource`
6. DB migration v8
7. datasource tests

### Slice 2 — ViewModel + DI

1. `QuickTemplateViewModel`
2. duplicate validation
3. `markUsed`
4. wire provider in `main.dart`
5. ViewModel tests

### Slice 3 — Strip UI

1. `QuickTemplatesStrip`
2. HomeScreen placement below `QuickAddBar`
3. tap template → `ExpenseViewModel.addTransaction()`
4. success → `QuickTemplateViewModel.markUsed()`
5. empty state `+ Tạo mẫu nhanh`

### Slice 4 — Manage UI

1. `ManageTemplatesSheet`
2. `QuickTemplateEditSheet`
3. create/edit/delete/pin
4. delete confirm
5. widget tests

### Slice 5 — Create from transaction

1. Add `Lưu làm mẫu` action to `TransactionDetailSheet`
2. map transaction → template
3. duplicate handling
4. snackbar success/duplicate/error

### Slice 6 — Backup / Restore

1. `BackupData.quickTemplates`
2. schema version v2
3. backup v1 compatibility
4. merge/replace restore behavior
5. backup/restore tests

## Acceptance Criteria

- User can create/edit/delete/pin quick templates.
- Delete template requires confirm and has no undo.
- `QuickTemplatesStrip` appears below `QuickAddBar`.
- Strip shows max 8 templates: pinned first, then frequent/recent.
- Empty strip shows compact `+ Tạo mẫu nhanh` entry.
- Tap template adds transaction immediately.
- Template add flow takes 1 tap from strip.
- `usageCount` and `lastUsedAt` update only after transaction add succeeds.
- User can create template from `TransactionDetailSheet` via `Lưu làm mẫu`.
- Exact duplicate template creation is blocked with friendly message.
- `ExpenseViewModel` does not own template CRUD.
- Backup/restore includes quick templates and remains compatible with v1 backups.
- Restore preserves templates even if category is unknown.

## Consequences

### Positive

- Reduces daily entry friction beyond category quick input.
- Keeps domain boundaries clean after ADR-0018.
- User-generated shortcuts survive backup/restore.
- Frequent/recent autofill makes feature useful without heavy setup.

### Negative

- Adds another model, datasource, ViewModel and provider.
- Backup schema bump to v2 increases test surface.
- UI coordination between `ExpenseViewModel` and `QuickTemplateViewModel` must avoid false `markUsed` on failed transaction add.

### Risks

- Duplicate validation only at app layer, not DB unique index. Low risk for single-device local app.
- Unknown category fallback can create transaction under `Khác`, which may surprise user after restoring old/lạ backup. Preserve-data behavior is still preferable.

## Out of Scope

- Smart suggestions / merchant memory.
- Fuzzy search.
- Auto-template generation.
- Recurring rule → template.
- `instant/editable` mode flag.
- Importing external files.

## References

- ADR-0008: UI/UX Home Backup Recurring Budget Pass
- ADR-0009: Search, Edit, Transaction Detail & Bulk Actions
- ADR-0017: Performance Sanity
- ADR-0018: Remove Pass-through Repositories
- `CONTEXT.md`

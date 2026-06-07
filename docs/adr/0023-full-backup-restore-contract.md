# ADR-0023: Full Backup & Restore Contract

**Date:** 2026-06-07  
**Status:** Accepted  
**Author:** hiennm11

## Context

`qlct.app` đã có backup/restore versioned JSON từ ADR-0007, hardening atomicity/file-size từ ADR-0010, và quick templates trong backup schema v2 từ ADR-0019.

Người dùng muốn hành vi rõ ràng hơn: **backup hết và restore hết**. Cần định nghĩa chính xác “hết” là gì để tránh 2 lỗi nguy hiểm:

1. Backup thiếu user-generated data → đổi máy mất dữ liệu.
2. Restore/delete-all không đồng bộ semantics → user tưởng đã xoá/khôi phục toàn bộ nhưng vẫn còn state cũ.

Đây là thay đổi file-format/restore-contract nên tạo ADR mới, không sửa lịch sử ADR đã Accepted.

## Decision

### 1. “Full backup” chỉ gồm active user financial data

Backup đầy đủ gồm source-of-truth user data:

- `transactions`
- `budgets`
- `recurringTransactions`
- `quickTemplates`
- `totalBudget`

Không backup:

- runtime/cache state
- `last_backup_time`
- filter/search/date/category state
- pagination state
- derived analytics (`ExpenseStats`, Monthly Review data, suggestion chips)
- DB implementation details (`transactions.search_text_normalized`)
- migration safety artifacts (`transactions_backup_v1`)

Rationale: backup phải portable, sạch, và đại diện cho dữ liệu tài chính người dùng. Runtime/cache/derived data có thể rebuild sau restore.

### 2. Bump backup schema to v3 with app identifier

Schema v3 thêm top-level `appId`:

```json
{
  "appId": "qlct.app",
  "schemaVersion": 3,
  "exportedAt": "2026-06-07T10:30:00.000Z",
  "appVersion": "1.0.0",
  "totalBudget": 20000000,
  "transactions": [],
  "budgets": [],
  "recurringTransactions": [],
  "quickTemplates": []
}
```

Rules:

- `currentSchemaVersion = 3`.
- `appId = "qlct.app"`.
- Export v3 luôn ghi `appId` ở top-level.
- V1/V2 backups không có `appId` vẫn restore được.
- Với `schemaVersion >= 3`, thiếu/sai `appId` → reject file.
- Unknown top-level fields được ignore nếu `schemaVersion <= currentSchemaVersion`.
- File có `schemaVersion > currentSchemaVersion` vẫn reject với message yêu cầu cập nhật app.

`BackupData` nên có default `appId` để parse file cũ, nhưng validation phải check raw JSON: v3+ bắt buộc đúng app id.

### 3. Stable field order

Export JSON giữ thứ tự top-level ổn định:

1. `appId`
2. `schemaVersion`
3. `exportedAt`
4. `appVersion`
5. `totalBudget`
6. `transactions`
7. `budgets`
8. `recurringTransactions`
9. `quickTemplates`

Rationale: JSON object unordered về mặt spec, nhưng field order ổn định giúp inspect/diff/debug/test snapshot dễ hơn.

### 4. Compact JSON, timestamped filename

Giữ compact JSON theo ADR-0010.

Đổi filename từ ngày-only sang timestamp:

```text
qlct-backup-yyyy-MM-dd-HHmmss.json
```

Rationale: tránh ghi đè nhiều backup trong cùng ngày, không thêm UX đặt tên file.

### 5. Restore merge semantics

Merge là non-destructive:

- Dùng `INSERT OR IGNORE` cho 4 domain tables.
- Nếu trùng UUID, current data wins; backup record bị skip.
- `totalBudget` chỉ được ghi từ backup nếu current value là `null` hoặc `0`.
- Không overwrite current `totalBudget` khi đã có giá trị.

Rationale: merge nghĩa là bổ sung dữ liệu, không phá cấu hình hiện tại. Nếu muốn file backup thắng tuyệt đối, dùng replace.

### 6. Restore replace semantics

Replace làm app user-data giống file backup:

- Xoá toàn bộ `transactions`.
- Xoá toàn bộ `budgets`.
- Xoá toàn bộ `recurring_transactions`.
- Xoá toàn bộ `quick_templates`.
- Ghi đè `totalBudget` từ backup.

Toàn bộ clear + insert phải chạy trong một DB transaction. Nếu insert fail, rollback cả delete phase.

Restore không generate recurring transactions. Restore chỉ là data operation; recurring generation vẫn chạy theo cold-start/home flow hiện có.

### 7. Delete-all semantics

Danger Zone “Xoá toàn bộ dữ liệu” phải đồng bộ với replace-empty semantics:

- clear `transactions`
- clear `budgets`
- clear `recurring_transactions`
- clear `quick_templates`
- clear/reset `totalBudget`

Không có Undo SnackBar cho delete-all. Confirm + optional safety backup là cơ chế bảo vệ.

### 8. Destructive flow preview current counts

Trước restore replace hoặc delete-all, UI phải hiển thị current data counts sẽ bị xoá:

- current transaction count
- current budget count
- current recurring count
- current quick template count

Restore replace dialog cũng hiển thị file counts đã parse từ backup.

Current counts phải lấy bằng SQL `COUNT(*)` qua DataSource count methods, không dùng ViewModel list hiện tại, vì transactions đang pagination và có thể chưa load đủ.

### 9. Safety backup before destructive actions

Trước restore replace hoặc delete-all, app hỏi:

```text
Sao lưu dữ liệu hiện tại trước không?
```

Default action: **Có**.

Nếu user chọn Có:

- tạo full backup hiện tại
- mở share sheet ngay
- lưu/update `last_backup_time` khi backup file được tạo/share flow chạy thành công

Nếu backup/share thất bại hoặc không chắc user đã lưu file, app hỏi lại:

```text
Backup chưa hoàn tất. Vẫn tiếp tục thao tác xoá/thay thế?
```

Default action: **Huỷ thao tác destructive**.

Rationale: destructive action cần đường lui rõ ràng, nhưng không auto-backup ngầm gây rác/ảo tưởng an toàn.

### 10. Post-restore UI state reset

Sau restore merge hoặc replace:

- refresh `ExpenseViewModel`
- refresh `BudgetViewModel`
- refresh `RecurringTransactionViewModel`
- refresh `QuickTemplateViewModel`
- clear category/date/date-range/search filters
- reset pagination/accumulated transaction pages về page đầu

Rationale: restore là external data mutation lớn. Giữ filter/search/pagination cũ dễ làm user tưởng restore lỗi vì list đang bị lọc hoặc stale.

### 11. Validation strictness

Backup restore là dữ liệu tài chính nên validation strict:

- File JSON phải là object.
- `schemaVersion` bắt buộc là int.
- v3+ bắt buộc `appId == "qlct.app"`.
- Domain arrays nếu có phải là array.
- Parse model lỗi → fail toàn bộ file.
- Không skip từng item lỗi trong backup restore.
- Giữ 50MB import guard.
- Không thêm checksum trong MVP.

Rationale: partial restore silently losing rows nguy hiểm hơn reject file hỏng.

### 12. UI wording

Backup/restore screen phải phân biệt rõ:

- **Sao lưu dữ liệu đầy đủ** — tạo file backup JSON restore được toàn bộ user financial data.
- **Xuất JSON (chỉ giao dịch)** — quick export chỉ transactions, không phải full backup.
- **Xuất CSV (chỉ giao dịch)** — quick export chỉ transactions.

Rationale: tránh user nhầm quick JSON export là full backup.

## Consequences

### Positive

- Full backup/restore contract rõ ràng, không mập mờ “hết”.
- File v3 tự nhận diện đúng app qua `appId`.
- V1/V2 backups vẫn restore được.
- Replace/delete-all semantics đồng bộ trên toàn app.
- Destructive actions an toàn hơn nhờ current counts + safety backup prompt.
- Restore UI ít gây hiểu nhầm vì filter/search/pagination reset.

### Negative

- Backup schema bump v3 tăng test surface.
- Thêm count methods vào DataSource interfaces.
- Destructive flows thêm dialog branching.
- Safety backup flow phụ thuộc share sheet, khó xác định tuyệt đối user đã lưu file hay chỉ đóng sheet.

### Neutral

- Không encryption/password trong MVP. UI nên nhắc file backup chứa dữ liệu chi tiêu và chỉ nên lưu/chia sẻ nơi tin cậy.
- Không backup derived data; restore có thể cần rebuild query/search shadow qua mapper/DB row logic như hiện tại.
- Không dùng SQLite raw file copy vì không portable cross-version.

## Implementation Notes

### Files likely affected

| File | Change |
|------|--------|
| `lib/models/backup_data.dart` | Add `appId`, bump schema v3 |
| `lib/models/backup_data.g.dart` | Regenerate |
| `lib/models/backup_data.freezed.dart` | Regenerate |
| `lib/services/backup_service.dart` | Export `appId`, validate v3, timestamp filename, strict messages, clear totalBudget on delete-all support |
| `lib/viewmodels/backup_viewmodel.dart` | Safety backup prompt support, execute restore flow, current counts, post-restore reset |
| `lib/views/backup_restore_screen.dart` | Wording, preview file/current counts, safety backup dialogs |
| `lib/viewmodels/expense_viewmodel.dart` | Clear filters + reset pagination after restore |
| `lib/data/datasources/*_local_datasource.dart` | Add count methods |
| `lib/data/datasources/sqlite_*_datasource.dart` | Implement SQL `COUNT(*)` |
| `CONTEXT.md` | Update Backup/Restore vocabulary and key decisions |

### Tests required

- `BackupData` v3 serialize includes top-level `appId`.
- V1 backup without `appId` validates/restores.
- V2 backup without `appId` validates/restores.
- V3 backup missing `appId` fails validation.
- V3 backup with wrong `appId` fails validation.
- Future schema `> currentSchemaVersion` fails validation.
- Unknown fields are ignored for supported schemas.
- Replace clears all 4 domains and writes `totalBudget`.
- Merge skips duplicate IDs and preserves current `totalBudget` when non-zero.
- Merge fills `totalBudget` when current value is `null`/`0`.
- Current counts use SQL `COUNT(*)`, not paginated ViewModel lists.
- Restore refresh clears filter/search/date/category and resets pagination.
- Export filename includes date + time `yyyy-MM-dd-HHmmss`.
- UI wording distinguishes full backup from transaction-only JSON/CSV export.

## Rejected Options

### Backup raw SQLite file

Rejected. Fast but not portable across schema versions/platforms and not inspectable.

### Backup all app state/cache

Rejected. Pulls runtime noise into backup, risks stale state and confusing restore behavior.

### Partial restore skipping corrupt rows

Rejected for backup restore. Acceptable for external import tools later, not for financial backup contract.

### Encrypt/password backup in MVP

Rejected for now. Adds password-loss/support burden. User controls share destination; UI warning is enough for MVP.

### Add checksum

Rejected for now. JSON parse + model validation already catches most corruption; checksum inside same file does not protect against malicious edit.

## References

- ADR-0007: Backup & Restore với JSON Schema Versioned
- ADR-0010: Release Hardening — Production Readiness
- ADR-0017: Performance Sanity
- ADR-0019: Quick Templates
- `CONTEXT.md`

# ADR-0015: Recurring Flow Audit — 5 Bugs & Fixes

**Date:** 2026-06-06
**Status:** Proposed
**Author:** hiennm11
**Extends:** ADR-0006 (Recurring Transactions)

## Context

ADR-0006 thiết kế recurring flow với 2 tầng chống duplicate (`nextRunAt` primary + `sourceRecurringId` safety net), generate 1 lần khi cold start, catch-up chỉ 1 tx. Audit full stack (model → datasource → repo → VM → widget → dialog) phát hiện 5 bugs — 1 critical, 2 medium, 2 low.

## Decision

### D1: Sửa safety net — so sánh với `rule.nextRunAt` thay vì `today` (Bug A, critical)

**Vấn đề:** Edit dialog ghi đè `nextRunAt`. Safety net hiện tại check duplicate bằng `today`:

```dart
// Hiện tại — sai
final today = DateTime(now.year, now.month, now.day);
final alreadyExists = allTx.any((tx) =>
  tx.sourceRecurringId == rule.id &&
  DateTime(tx.date.year, tx.date.month, tx.date.day) == today
);
```

Nếu tx gốc sinh 6/6, user edit `nextRunAt` → 8/6, cold start 8/6 → safety net check `today` (8/6) → không tx ngày 8/6 → sinh trùng.

**Fix:** So sánh với `rule.nextRunAt` (ngày rule dự kiến sinh), không phải `today`:

```dart
// Sửa
final ruleDate = DateTime(rule.nextRunAt.year, rule.nextRunAt.month, rule.nextRunAt.day);
final alreadyExists = allTx.any((tx) =>
  tx.sourceRecurringId == rule.id &&
  DateTime(tx.date.year, tx.date.month, tx.date.day) == ruleDate
);
```

**Lý do:** Mục tiêu là ngăn sinh trùng cho ngày `nextRunAt` đại diện. Nếu đã có tx ngày đó với cùng `sourceRecurringId` → skip. Với catch-up (nextRunAt 60 ngày trước), `ruleDate` trong quá khứ → không tx nào match → vẫn generate bình thường.

**Test thêm:**
- Edit nextRunAt → future date → cold start ngày đó → chỉ 1 tx
- Edit nextRunAt → same day as generate → cold start → không sinh tx mới

---

### D2: Bọc `add()` + `updateNextRunAt()` trong database transaction (Bug B, medium)

**Vấn đề:** ADR-0006 yêu cầu atomicity nhưng implementation không có. Nếu app crash giữa `txRepo.add()` và `updateNextRunAt()` → tx đã INSERT, nextRunAt chưa advance → cold start sau match lại (D1 catch). WAL mode giảm rủi ro nhưng không thay thế explicit transaction.

**Fix:** Wrap trong `DatabaseHelper.runInTransaction()`. Cần thêm optional `DatabaseExecutor?` parameter vào datasource methods để nhận transaction context:

```dart
// SqliteTransactionDataSource
Future<void> insertWithExecutor(DatabaseExecutor db, Transaction tx) async {
  await db.insert('transactions', _toMap(tx));
}

// Trong checkAndGenerate
await _dbHelper.runInTransaction((txn) async {
  await _txDatasource.insertWithExecutor(txn, tx);
  await _recurringDatasource.updateNextRunAtWithExecutor(txn, rule.id, next);
});
```

**Impact:** Thêm `DatabaseHelper` dependency vào VM, thêm 2 method vào datasource. Cập nhật mock trong test.

---

### D3: Per-rule try-catch — không bỏ qua rules sau khi 1 rule fail (Bug C, medium)

**Vấn đề:** Loop `for (final rule in dueRules)` không có try-catch trong. Exception ở rule #2 → break loop → rules #3-N bị bỏ.

**Fix:** Bọc per-rule trong try-catch, log lỗi + tiếp tục:

```dart
final errors = <String>[];
for (final rule in dueRules) {
  try {
    // existing duplicate check + generate logic
  } catch (e, stack) {
    debugPrint('❌ Failed to generate for rule ${rule.id}: $e');
    errors.add(rule.id);
    // continue to next rule
  }
}
if (errors.isNotEmpty) {
  _errorMessage = 'Lỗi sinh ${errors.length} giao dịch định kỳ';
}
```

---

### D4: Query SQL thay `txRepo.getAll()` (Bug D, low — deferred)

**Vấn đề:** Load toàn bộ transaction vào memory để check duplicate. O(n) với dataset lớn.

**Fix:** Thêm method `existsBySourceAndDate` vào `TransactionRepository`:

```sql
SELECT COUNT(*) FROM transactions
WHERE source_recurring_id = ? AND date LIKE '2026-06-06%'
```

**Defer:** Dataset hiện nhỏ (<1000 tx), chưa gây performance issue thực tế. Làm khi cần.

---

### D5: Sửa label edit dialog — "Bắt đầu" → "Ngày chạy kế tiếp" khi edit (Bug E, low)

**Vấn đề:** Dialog hiển thị "Bắt đầu:" cho cả add và edit. Trong edit, field này thực chất là `nextRunAt`.

**Fix:**

```dart
// Trong RecurringEditDialog.build()
Row(children: [
  Text(isEdit ? 'Ngày chạy kế tiếp: ' : 'Bắt đầu: '),
  TextButton(onPressed: _pickDate, child: Text(dateStr)),
]),
```

1 dòng, không đổi behavior.

---

## Considered Options

### D1 — So sánh theo `rule.nextRunAt` (chọn)
- **Pros:** Chính xác — mỗi rule chỉ sinh 1 tx cho mỗi ngày nextRunAt. Không bị edit phá.
- **Cons:** Catch-up quá khứ → check date quá khứ → luôn pass (đúng intent).
- **Rejected:** `max(lastGeneratedDate, nextRunAt)` — phức tạp hoá.

### D2 — Database transaction (chọn)
- **Pros:** Atomicity như ADR-0006. Không partial state.
- **Cons:** Cần thêm optional `DatabaseExecutor` param vào datasource.
- **Rejected:** Defer hoàn toàn — WAL mode đủ an toàn cho single-device, nhưng ADR-0006 đã commit.

### D3 — Per-rule try-catch (chọn)
- **Pros:** Robust. 1 rule fail không block rules khác.
- **Cons:** Cần accumulate errors.
- **Rejected:** Abort toàn bộ — quá cứng nhắc.

### D4 — SQL query (deferred)
- **Pros:** O(1) memory.
- **Cons:** Dataset nhỏ hiện tại, không cần gấp.

### D5 — Label (chọn)
- **Pros:** 1 dòng. UX rõ ràng.

---

## Consequences

- **Positive:**
  - Bug A fixed → edit recurring an toàn, không sinh trùng
  - Bug B fixed → nhất quán ADR-0006 atomicity
  - Bug C fixed → robust khi DB lỗi
  - D5 fixed → UX rõ ràng hơn

- **Negative:**
  - D1 thay đổi logic safety net → cần update test cũ
  - D2 cần thay đổi datasource interface → cập nhật mock

- **Test update:**
  - `recurring_viewmodel_test.dart`: +3 tests (edit+duplicate, per-rule error, atomicity)
  - `recurring_integration_test.dart`: +1 test (edit → no duplicate)
  - Update test `does NOT generate duplicate when tx with same source+date exists` — logic so sánh `today` → `rule.nextRunAt`

- **Total tests dự kiến:** 359 → ~364

- Schema không đổi. Migration không cần.

## Implementation Order

| Priority | Bug | Effort | Files |
|----------|-----|--------|-------|
| 1 | D5 (label) | 1 dòng | `recurring_edit_dialog.dart` |
| 2 | D1 (safety net fix) | ~10 dòng | `recurring_viewmodel.dart` |
| 3 | D3 (per-rule try-catch) | ~10 dòng | `recurring_viewmodel.dart` |
| 4 | D2 (atomicity) | ~30 dòng | `recurring_viewmodel.dart` + datasources |
| 5 | D4 (SQL query) | Defer | — |

---

## References

- ADR-0006: Recurring Transactions (original design)
- ADR-0004: SQLite Storage & Migration
- `lib/viewmodels/recurring_viewmodel.dart` — `checkAndGenerate()`, `_calculateNextRun()`
- `lib/widgets/recurring_edit_dialog.dart` — label "Bắt đầu"

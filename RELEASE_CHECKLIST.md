# Release Checklist — qlct.app v1.0.0

## Trước khi build
- [ ] `flutter test` — all tests pass (249+ test cases)
- [ ] `flutter analyze` — zero errors, zero warnings
- [ ] `flutter build apk --release --dart-define=SENTRY_DSN=$env:SENTRY_DSN`
- [ ] Kiểm tra `sentry_flutter` init không throw khi thiếu DSN
- [ ] Xoá `debugPrint` còn sót trong production path (replace = logger nếu cần)

---

## Migration (SharedPreferences → SQLite)
- [ ] Test trên máy Android thật có sẵn data SharedPreferences cũ
- [ ] Mở app → verify tất cả giao dịch cũ migrate sang SQLite
- [ ] Kiểm tra flag `migrated_to_sqlite_v1` = true trong SharedPreferences
- [ ] Kill app giữa chừng migration → mở lại → retry thành công (không mất data)
- [ ] Test với SharedPreferences key rỗng, null, corrupt JSON → không crash

## Recurring Transactions
- [ ] Cold start → recurring rule due được generate 1 transaction (không duplicate)
- [ ] Kiểm tra `nextRunAt` advance đúng (daily +1d, weekly +7d, monthly +1mo)
- [ ] Deactivate 1 rule → rule đó không generate nữa
- [ ] Reactivate rule → `nextRunAt` tính từ hiện tại, không backfill
- [ ] Tắt app, đổi ngày giờ system → mở app → generate không duplicate

## Budget Alert
- [ ] Thêm giao dịch vượt alert threshold → BudgetStatus = warning (vàng)
- [ ] Thêm giao dịch vượt limit → BudgetStatus = exceeded (đỏ)
- [ ] Tap vào budget card → filter danh sách giao dịch đúng category
- [ ] Sửa budget limit → status update ngay lập tức
- [ ] Xoá budget → không còn hiển thị trong danh sách

## Backup & Restore
- [ ] Backup: tạo file JSON → share qua system sheet → mở file kiểm tra format đúng
- [ ] Restore merge: file có 5 transaction mới + 3 trùng ID → chỉ import 5 mới
- [ ] Restore replace: clear all → import từ file → verify đúng data file, không dư
- [ ] Test với file JSON corrupt → hiển thị lỗi rõ ràng, không crash
- [ ] Test với file schema version cao hơn → từ chối + message thân thiện
- [ ] Test với file >50MB → từ chối + message
- [ ] Test restore với 10K+ transactions → merge < 3 giây, replace < 2 giây
- [ ] Test restore trên máy sạch (mới cài app) → đủ budgets + recurrings + totalBudget

## Export
- [ ] Export CSV: mở file → verify header + ít nhất 1 dòng đúng format
- [ ] Export JSON: verify cấu trúc JSON hợp lệ
- [ ] Export với filter đang active → context-aware label "Xuất kết quả lọc (N mục)"
- [ ] Export với search query → label hiển thị đúng số kết quả
- [ ] Bulk export (multi-select) → CSV chứa đúng các dòng đã chọn

## Voice Input
- [ ] Cấp microphone permission → hiện dialog xin quyền
- [ ] Từ chối permission → hiện message hướng dẫn bật lại trong Settings
- [ ] Nói "năm mươi nghìn" → parse đúng 50000
- [ ] Nói "50 ngàn cà phê" → parse 50000 + match category "Cà phê"
- [ ] Nói category không khớp → fallback "Khác"
- [ ] Voice từ QuickAddBar, QuickVoiceButton, CustomInputWidget → cả 3 hoạt động

## Crash Reporting (Sentry)
- [ ] Verify Sentry dashboard nhận được event test (gây crash thủ công)
- [ ] Gây crash bằng `throw Exception('test')` trong onTap → xuất hiện trong Sentry < 30s
- [ ] Verify breadcrumbs không chứa PII (transaction amount, note)
- [ ] Verify release health metrics hiển thị đúng version

## Performance
- [ ] Cold start < 2 giây (trên máy thật, 10K transactions)
- [ ] Scroll danh sách 10K transactions mượt (không jank)
- [ ] Voice recognition latency < 500ms từ tap đến listening
- [ ] Backup 10K transactions < 3 giây (create + write file)
- [ ] App size < 30MB (APK release)

## Undo / Delete Safety
- [ ] Xoá 1 giao dịch → hiện SnackBar "Đã xoá" với nút "Hoàn tác" (5 giây)
- [ ] Hoàn tác thành công → giao dịch trở lại danh sách
- [ ] Bulk delete (multi-select) → confirm dialog → undo được
- [ ] Xoá toàn bộ dữ liệu (gear menu) → confirm dialog → undo được

## Settings / Misc
- [ ] Gear menu hiển thị đủ: Export CSV, Export JSON, Backup, Restore, About
- [ ] About dialog hiển thị version + link
- [ ] Pull-to-refresh hoạt động trên HomeScreen
- [ ] App không crash khi rotate màn hình
- [ ] App không crash khi background/foreground
# ADR-0047: P3 #4 — Settings: Auto-purge (move from CategoryManagement)

**Status:** Accepted 2026-06-14
**Type:** Contract-ref (UI move + small bug fix, không schema/dependency/release policy change)
**Linked contract:** `docs/specs/p3-settings-auto-purge-contract.html`

## Context

P3 polish batch 2026-06-14 sau khi P3 #1 (bulk-archive) + P3 #2 (auto-purge) + P3 #3 (month picker) merged. User report: FAB `+` ở `CategoryManagementScreen` che SwitchListTile auto-purge trong Trash section. Vì setting là user-configurable global (không phải per-category), đúng pattern là move sang Settings screen full-screen — vừa fix bug FAB, vừa tạo scaffold cho future settings.

`AutoPurgePrefs` (SharedPreferences wrapper) đã có ở `lib/data/preferences/auto_purge_prefs.dart` từ P3 #2. `setEnabled(bool)` / `isEnabled()` API stable. Reuse, không invent.

## Decision

1. **New file** `lib/views/settings_screen.dart` — full-screen `Scaffold` + AppBar "Cài đặt" + back button + `ListView` với 1 section header "Dữ liệu" + 1 `ListTile` auto-purge (subtitle "30 ngày", switch bound to `AutoPurgePrefs`).
2. **Modify** `lib/views/category_management_screen.dart` — xoá `SwitchListTile` auto-purge khỏi Trash section. Giữ heading "Thùng rác" + warning banner (nếu có items sắp purge) + restore/purge buttons.
3. **Modify** `lib/views/home_screen.dart` — thêm 1 `PopupMenuItem` "Cài đặt" (icon `Icons.settings`) giữa "Quản lý danh mục" và divider "Giới thiệu". Tap → `Navigator.push(MaterialPageRoute(builder: (_) => const SettingsScreen()))`.

Mirror contract HTML 5 sections (§1 entry, §2 layout, §3 default/behavior, §4 trash after, §5 out-of-scope). Không tạo full ADR (5-15 dòng rule): không schema bump, không dependency change, không release policy change.

## Consequences

- 2 files thay đổi + 1 new file. Stateless `SettingsScreen` chỉ giữ `bool _autoPurgeEnabled` local state + `AutoPurgePrefs.isEnabled()` load init + `setEnabled()` on change.
- Bug FAB `+` che switch tự fix (switch đã move). 
- Settings screen = scaffold 1-section hiện tại. 6 candidates P+ (theme, currency, interval, voice lang, budget carry, clear all) để grill riêng khi demand xuất hiện.
- 0 schema migration. 0 dependency change. 0 release policy change.
- Glossary: "Cài đặt" (Settings), "Tự động dọn thùng rác" (Auto-purge), "Dữ liệu" (Data section) — 3 term mới, add to `CONTEXT.md` trong Phase 5.

## See also

- `docs/specs/p3-settings-auto-purge-contract.html` — visual + data-* binding
- `docs/adr/0045-p3-auto-purge-2026-06-14.md` — base auto-purge feature (giờ chỉ move, không thay đổi logic)
- `docs/adr/0037-category-management-ux-v2.md` — base category management (Trash section)
- `docs/adr/0024-release-versioning-device-policy.md` — version bump + install

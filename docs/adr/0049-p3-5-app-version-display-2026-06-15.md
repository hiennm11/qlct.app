# ADR-0049: App version display in Settings (P3 #5)

**Date:** 2026-06-15
**Status:** Accepted
**Type:** Full ADR (dependency add — `package_info_plus` ^9.0.1 explicit declaration)

## Context

Smoke test v1.7.0+2026061501 cần cách verify app version trên device mà không phải `adb shell dumpsys package`. User explicit request: thêm version display trong Settings.

Hiện tại Settings screen (`lib/views/settings_screen.dart`) chỉ có 1 section "Dữ liệu" (auto-purge switch). Không có UI hiển thị version ở bất kỳ đâu trong app.

## Decision

Thêm section "Thông tin" + row "Phiên bản" cuối `SettingsScreen` body ListView:

- **Section header** mirrors "Dữ liệu" pattern: `Row(Icon + Text)` với `Icons.info_outline` 18px + text "THÔNG TIN" 12 semibold grey-600 letter-spacing 0.5.
- **Row**: `ListTile` với `leading: Icons.smartphone`, `title: 'Phiên bản'`, `trailing: Text(versionString)`, `enabled: false` (read-only info). Read-only match Android Settings → About → Version convention.
- **Value format**: `'{version} (build {buildNumber})'` — ví dụ `"1.7.0 (build 2026061501)"`. Dùng format 2 (`{version} (build {build})`) thay vì format 1 (`{version}+{build}`) vì build number dễ scan hơn ở dạng parentheses.
- **Source**: `package_info_plus: ^9.0.1` — load async trong `initState`, mirror pattern `_loadAutoPurgePref`. Initial state = `'...'` (placeholder) trong khi chờ async load.

## Self-detect 3 câu hỏi

1. Có bump schema version (SQLite/backup) không? **Không** — chỉ display existing data, không thêm/sửa persisted field.
2. Có thay đổi dependency hoặc layer architecture không? **CÓ** — add explicit `package_info_plus: ^9.0.1` vào `pubspec.yaml` dependencies (transitive dep đã có sẵn trong pubspec.lock, nhưng cần declare explicit để `flutter analyze` pass `depend_on_referenced_packages` lint và version pinning rõ ràng).
3. Có thay đổi version policy / release process không? **Không** — version format vẫn `MAJOR.MINOR.PATCH+BUILD` per ADR-0024.

→ Câu 2 = "có" → viết **full ADR**.

## Dependencies

`package_info_plus: ^9.0.1` — official Flutter Community Plus plugin, BSD-3-Clause, ~5KB compiled. Ổn định 3+ năm, dùng cho cùng purpose (app version display) ở hầu hết Flutter production apps.

**Lý do không tự roll**: `PlatformDispatcher` không expose `versionName`/`versionCode` qua API ổn định — phải platform-channel manual cho mỗi platform (Android PackageManager, iOS Bundle.infoDictionary, Windows GetVersionEx). `package_info_plus` wrap tất cả 3 platforms (Android/iOS/Windows/Linux/macOS) — vì codebase có thể expand sang platform khác, dùng plugin là đúng.

## Layer impact

- **UI layer**: 1 new section trong `SettingsScreen`. Không động chạm VM/datasource.
- **No business logic change**: chỉ display data, không có input.
- **No state change**: `_appVersionDisplay` là local widget state, không propagate lên Provider.

## Alternatives considered

1. **Hardcode version string trong widget** — KHÔNG. Manual sync mỗi lần bump version = sai lầm chắc chắn. Source phải từ package metadata.
2. **Đọc từ `pubspec.yaml` qua `rootBundle.loadString('pubspec.yaml')`** — KHÔNG. Bundle assets trong release build không include `pubspec.yaml`. Chỉ work ở debug.
3. **Add từng platform-channel manual** — quá nhiều boilerplate (5+ files, 100+ dòng), không bền vững. Plugin đã cover.
4. **Hiển thị version trong About dialog (snackbar trigger)** thay vì Settings row** — KHÔNG. Settings là chuẩn Android, user dễ tìm hơn.

## Out of scope

- Hiển thị database schema version (SQLite v15, backup v9) — đã show ở About dialog nếu có; user không request.
- Tap row để copy version vào clipboard — YAGNI, nếu user cần sẽ request sau.
- "What's new" link tới CHANGELOG — YAGNI per CONTEXT §Verify pass 2026-06-14.
- Force update check / version comparison — không có server.
- Locale-aware version label (e.g. "Phiên bản" → "Version" ở `en_US`) — chưa có localization, YAGNI.

## Verify pass

Smoke test device 21091116C sau khi install APK build mới (v1.7.0+2026061502):
- Mở Settings → scroll xuống dưới cùng → thấy section "Thông tin" → row "Phiên bản" → value "1.7.0 (build 2026061502)".
- Row không tap được (read-only, info display, no ripple).
- Widget test: `find.byKey(Key('state-version-row'))` findsOneWidget. Value string dynamic → assert qua `Text` widget match regex `\d+\.\d+\.\d+ \(build \d+\)`.
- Cross-check version: `flutter pub deps` không show warning `depend_on_referenced_packages` nữa.

## Flutter Key binding

| HTML | Flutter widget | Test |
|------|----------------|------|
| `data-state="version-row"` | `Key('state-version-row')` | `find.byKey(Key('state-version-row'))` |

Version string dynamic → assert qua `find.text(matchingRegex)`, không qua Key.

## Implementation

File: `lib/views/settings_screen.dart`
- Line 2: add `import 'package:package_info_plus/package_info_plus.dart';`
- Line ~28: add `String _appVersionDisplay = '...';`
- Line ~37: call `_loadAppVersion()` trong `initState`
- Line ~48: add `_loadAppVersion()` async method (mirror `_loadAutoPurgePref`)
- Line ~97: add section header + ListTile row ở cuối body ListView

File: `pubspec.yaml` line 65: add `package_info_plus: ^9.0.1` explicit.

## References

- Spec: `docs/specs/p3-5-app-version-display-contract.html` (visual mockup + Key binding table)
- Related ADR: ADR-0047 (Settings screen scaffolding, P3 #4 auto-purge), ADR-0024 (release versioning)
- Plugin docs: https://pub.dev/packages/package_info_plus

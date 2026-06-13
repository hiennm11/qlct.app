## Agent skills

### Issue tracker

Issues tracked in GitHub Issues via `gh` CLI on `hiennm11/qlct.app`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical roles map directly: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at root + `docs/adr/`. See `docs/agents/domain.md`.

### Build, install, release

Canonical install command: `flutter install -d <serial>` (ADR-0024 addendum 2026-06-14). `adb` chỉ dùng cho debug/inspection. Hotfix = RC bump trên BUILD (`yyyyMMdd` → `yyyyMMdd01` → …), không tạo git tag mới cho đến khi promote main device. Full procedure: `RELEASE_CHECKLIST.md` → "Build & Install" section. Versioning/device policy: `docs/adr/0024-release-versioning-device-policy.md`.

### Flutter skills

Project skills in `.agents/skills/`. Load via `skill` tool when coding.

| Skill | When to use |
|-------|-------------|
| `flutter-add-widget-test` | Viết component test với WidgetTester |
| `flutter-add-integration-test` | Viết integration test, automate user flow |
| `flutter-add-widget-preview` | Preview widget để test UI tương tác |
| `flutter-apply-architecture-best-practices` | Refactor/new project theo layered architecture |
| `flutter-build-responsive-layout` | Layout thích ứng mobile/tablet/desktop |
| `flutter-fix-layout-issues` | Sửa lỗi overflow, unbounded constraints |
| `flutter-implement-json-serialization` | Tạo fromJson/toJson thủ công |
| `flutter-setup-declarative-routing` | Setup go_router, deep linking |
| `flutter-setup-localization` | Đa ngôn ngữ với intl |
| `flutter-use-http-package` | Gọi REST API với package:http |

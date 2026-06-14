## Agent skills

### Issue tracker

Issues tracked in GitHub Issues via `gh` CLI on `hiennm11/qlct.app`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical roles map directly: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at root + `docs/adr/`. See `docs/agents/domain.md`.
`grill-with-docs` is the global producer skill (gộp `/grill-me`) cho cả `CONTEXT.md`,
`docs/adr/`, và `docs/specs/` artifacts.

### Workflow

5 phase, gọi theo thứ tự. **Không skip phase.**

| Phase | Skill | Vai trò | Output |
|-------|-------|---------|--------|
| 1. Grill | `/grill-with-docs` | BA stress-test plan/requirement chống `CONTEXT.md` + relevant ADRs | Decided: requirement rõ, edge cases, terminology chốt |
| 2. Contract | `/to-contract` | Viết `docs/specs/<feature>-contract.html` (Tailwind CDN, `data-*` machine-readable) | 1 HTML file, mở browser test được |
| 3. Decide | `/write-adr` | 1 mode, **tự detect full vs contract-ref** bằng 3 câu hỏi (xem dưới) | ADR mới trong `docs/adr/` |
| 4. Implement | `/implement` | Code map 1:1 với `data-*` qua Flutter Key binding (xem dưới) | Production code + tests |
| 5. Update | `/update-context` | Cập nhật `CONTEXT.md` vocab/rule/lesson mới | Cùng commit với code (atomic 1-commit) |

**Phase 5 trigger** (gọi mỗi feature/bug chốt, sau `/implement` pass tests, trước commit):
- Vocab mới (term chưa có glossary)
- Quy tắc mới (architectural rule chưa document)
- Bài học mới (debug insight, hotfix pattern)

#### `/write-adr` self-detection

Agent check 3 câu hỏi theo thứ tự. **Bất kỳ câu nào = "có"** → viết **full ADR** (~100 dòng, giữ pattern cũ):

1. Có bump schema version (SQLite/backup) không?
2. Có thay đổi dependency hoặc layer architecture không?
3. Có thay đổi version policy / release process không?

Nếu cả 3 = "không" → **contract-ref ADR** (5-15 dòng, link contract HTML làm đặc tả UI/logic).

#### `/implement` Key binding

| HTML contract | Flutter widget | Test |
|---------------|----------------|------|
| `data-state="active"` | `Key('state-active')` | `find.byKey(Key('state-active'))` |
| `data-is-valid="false"` | `Key('is-valid-false')` | `expect(find.byKey(...), findsOneWidget)` |
| `data-count="3"` | n/a (dynamic) | Assert qua VM, không qua Key |

Key chỉ encode **enum/boolean**. Number/string state test qua VM getter assertion.

#### Scope boundary

| | Contract (`docs/specs/*.html`) | Full ADR (`docs/adr/*.md`) |
|---|---|---|
| Bind | UI state, interaction, edge case, validation | Schema version, dependency, layer, release policy |
| Schema bump? | Không | Có (1 trong 3 câu hỏi trên) |
| Format | HTML+Tailwind+`data-*` | Markdown decision record |

Contract **không thay thế** full ADR cho arch/policy changes.

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

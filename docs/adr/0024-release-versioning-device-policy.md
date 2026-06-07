# ADR-0024: Release Versioning & Device Promotion Policy

**Date:** 2026-06-08  
**Status:** Accepted  
**Author:** hiennm11

## Context

`qlct.app` là local-first personal finance app. Dữ liệu chính nằm trên device của người dùng, gồm SQLite database và SharedPreferences settings. App đã có:

- SQLite migrations
- Backup/restore JSON schema v3 theo ADR-0023
- Release hardening theo ADR-0010
- Release checklist theo ADR-0012
- 2 thiết bị vận hành thực tế: **test device** và **main device**

Nhưng trước ADR này, release process vẫn chưa có rule chính thức cho:

1. Cách bump app version.
2. Khi nào dùng PATCH/MINOR/MAJOR.
3. Build nào được phép cài lên main device.
4. Release gate bắt buộc trước khi promote.
5. Rollback/restore gate khi release fail.

Vì app quản lý dữ liệu tài chính cá nhân và có migration/restore flows, release discipline phải được coi là một phần của safety model, không chỉ là thao tác build APK.

## Decision

### 1. Versioning

App version follows:

```text
MAJOR.MINOR.PATCH+BUILD
```

Git release tag follows app version only:

```text
vMAJOR.MINOR.PATCH
```

Rules:

- `PATCH`: bug fix, copy/UI polish, non-breaking refactor, test-only/doc-only release.
- `MINOR`: thêm feature mới, thêm workflow mới, thêm analytics/read-only module.
- `MAJOR`: breaking data model, breaking DB schema contract, breaking restore contract, destructive migration risk.
- `BUILD`: dùng dạng ngày `yyyyMMdd` cho stable release; nếu cùng ngày có nhiều release candidate, thêm số thứ tự bằng cách append 2 digits (`yyyyMMdd01`, `yyyyMMdd02`).
- Trước release, luôn bump `version:` trong `pubspec.yaml`.
- Trước release, luôn ghi release notes hoặc checklist result trong `RELEASE_CHECKLIST.md`.
- Git tag không include `+BUILD`; tag `v1.0.1` đại diện cho release `version: 1.0.1+20260608`.

Example:

```yaml
version: 1.0.0+1
version: 1.0.1+20260608
version: 1.1.0+20260609
version: 2.0.0+20260610
```

```text
git tag: v1.0.0, v1.0.1, v1.1.0, v2.0.0
```

Rationale: date-based build number dễ đọc hơn `+N`, vẫn tăng đơn điệu theo thời gian, đủ cho sideload cá nhân.

### 2. Device policy

Device roles:

- **Test device**: cài dev/beta/release-candidate builds trước.
- **Main device**: chỉ cài stable release builds đã pass test device.

Rules:

- Main device không dùng để thử breaking build.
- Main device chỉ nhận build đã pass release gate.
- Any build touching migration, restore, backup, DB schema, or delete-all flow must be tested on test device before main device.
- Never test destructive or schema-changing builds directly on main device.

### 3. Release gate

A build is allowed to release only if all are true:

- App opens successfully on current DB.
- Migration from previous supported versions works, if applicable.
- Backup export works.
- Restore merge works.
- Restore replace works.
- Search opens and returns expected data.
- Transaction add/edit/delete smoke test passes.
- Monthly Review opens without crash.
- No data loss is observed in smoke test.
- Test device passed.

Release formula:

```text
Release Allowed = Stable App + Migration Safe + Backup Safe + Restore Safe + Test Device Passed
```

Short rule:

```text
Only release when:
App Stable + Migration Safe + Backup Safe + Restore Safe + Test Device Passed
```

### 4. Backup/restore gate

Backup/restore rules follow ADR-0023 and are required in every release smoke test:

- Backup schema version must be explicitly recorded.
- Backup must include `appId = "qlct.app"` for schema v3+.
- Restore must fail safely with clear error if file is invalid, incompatible, wrong-app, or future-schema.
- Backup must include only persisted user data, not derived/runtime state.
- Restore replace and delete-all destructive flows must show current counts and safety backup prompt.
- Restore smoke test must include at least one merge or replace flow before a build can be promoted to main device.

Critical rule:

> Không có release nào được coi là hoàn tất nếu chưa được test trên device test với ít nhất một migration hoặc restore smoke test.

### 5. Rollback rule

- Every release must keep at least one known-good backup sample.
- If release fails smoke test, do not promote to main device.
- If a release candidate fails, fix the issue, bump `BUILD` by `+1`, and re-test on test device first.
- If main device install is needed, create/share a fresh full backup before installing.
- If installed build shows data-loss risk, stop using the build, restore from known-good backup, and create a follow-up fix release.

## Consequences

### Positive

- Main device stays stable.
- Migration/backup/restore become mandatory release safety gates.
- Version bump is simple and consistent.
- Release checklist becomes operational, not aspirational.
- Failed release candidates cannot silently become main-device builds.

### Negative

- Every release requires manual device work.
- Even small PATCH releases need build number bump and smoke test.
- Release process takes longer than direct sideload.

### Neutral

- No source code change required.
- No CI/CD requirement yet.
- No Play Store release process yet; current target is personal sideload usage.

## Implementation Notes

Files to keep aligned:

- `pubspec.yaml` — app version and build number.
- `RELEASE_CHECKLIST.md` — per-release verification record.
- `CONTEXT.md` — release section points to checklist and release policy.

Checklist must not contradict ADR-0023. Specifically, delete-all has **no Undo**; protection is confirm dialog + safety backup prompt.

## Rejected Options

### Increment-only build number

Rejected. `+1`, `+2`, `+3` ngắn nhưng khó đọc khi nhìn APK/tag history. Date-based build number trace release date tốt hơn.

### Main device as test device

Rejected. Local-first financial data makes this too risky.

### Release without restore smoke test

Rejected. Backup/restore is the rollback mechanism. A release without tested restore is not safe.

## References

- ADR-0010: Release Hardening — Production Readiness
- ADR-0012: Release Verification — V1.0.0 Go-Live Gate
- ADR-0023: Full Backup & Restore Contract
- `RELEASE_CHECKLIST.md`

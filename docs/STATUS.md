# NeonSaga — Status (genesis)

**Snapshot date:** 2026-05-28
**Product source of truth:** `docs/PRODUCT.md`
**Roadmap source of truth:** `ROADMAP.md`
**规范 source of truth:** `CLAUDE.md`

## What ships today

No user-facing product yet. The genesis toolchain is wired and a minimal
`@main` app shell builds + launches (shows "NeonSaga / core 0.0.0-genesis").
`make verify` and `make verify-full` are both green on this skeleton. No
production feature code yet — Stage 1 begins that. The 5-tab IA, real views,
`@Model` classes, and services are empty placeholders until Stage 1.

## What's next

Stage 1 (HEALTH to Whoop/Oura + AI, 3-week deadline). Before any code:

1. Write `CONTRACT.md` for Stage 1 in a worktree from
   `docs/templates/CONTRACT.md`.
2. Codex-review the CONTRACT (first review of two).
3. Lead writes failing RED tests against the CONTRACT.
4. Codex-review the RED tests (second mini-review).
5. Dispatch worker subagent for implementation.
6. Codex-review the worker diff (second main review).
7. Lead integrates + runs `make verify-full` + iPhone install.
8. `git tag v0.1`.

See `ROADMAP.md` §2 for Stage 1 scope and Plan B cut order.

## File counts at genesis

| Surface | Files |
|---|---|
| `NeonSagaCore/Sources/NeonSagaCore/` | 1 (`NeonSagaCore.swift` — genesis version seed) |
| `NeonSagaCore/Sources/NeonSagaCoreTests/` | 1 (`main.swift` — custom runner + genesis smoke test) |
| `NeonSaga/App/` | 1 (`NeonSagaApp.swift` — minimal `@main` shell) |
| `NeonSaga/Models/` | 0 |
| `NeonSaga/Services/` | 0 |
| `NeonSaga/Views/` | 0 |
| `NeonSagaTests/` | 1 (`GenesisSmokeTests.swift` — bundle smoke) |
| `docs/adr/` | 1 ADR + template (ADR-001 accepted) |

Updated after each Stage exit per `CLAUDE.md` §1.4.

## Verification state

- `make verify`: **green** — pre-commit hooks (swift-format lint + hygiene) +
  `make build-core` + `make test-core` (custom runner: `2 passed, 0 failed`).
- `make verify-full`: **green** — `make verify` + `make gen` + iOS `make build`
  + iOS `make test` (the minimal `@main` shell + bundle smoke pass on the
  iPhone 17 simulator). Feature-level build/test depth begins at Stage 1
  (genesis bootstrap clause, `CLAUDE.md` §1.9).
- Latest iOS test count: 1 (`GenesisSmokeTests` bundle smoke)
- Latest screenshots: N/A — `docs/screenshots/` empty until Stage 1 ships

## Git state

- Default branch: `main` — protected (PRs required before merge; force-push +
  deletion blocked; enforced for admins too).
- Workflow: all changes land via feature branch → PR → Codex review → merge
  (`CLAUDE.md` §8). Genesis specs + ADR-001 are the root commit (`3b098d4`);
  the build toolchain + app shell land via PR #1.
- Tags: none (first tag `v0.1` at Stage 1 exit).

## Pending genesis tasks

These are pre-Stage-1 setup tasks. Track and complete before Stage 1
CONTRACT starts. Maintaining them here (not in `ROADMAP.md`) keeps the
ROADMAP focused on product stages.

- [x] Owner approves `CLAUDE.md`
- [x] Owner approves `docs/ROADMAP.md`
- [x] `git init` + first commit (`init: NeonSaga genesis`)
- [x] Wire `Makefile`
- [x] Wire `project.yml` (XcodeGen skeleton)
- [x] Wire `NeonSagaCore/Package.swift`
- [x] Seed `NeonSagaCore/Sources/NeonSagaCoreTests/main.swift` (custom runner)
- [x] Wire `.swift-format` and `.pre-commit-config.yaml`
- [x] `.claude/skills/tdd/` skill in place
- [x] `AGENTS.md` symlink → `CLAUDE.md`
- [x] `make verify` green on empty skeleton
- [x] Minimal `@main` app shell + bundle smoke → `make verify-full` green

## Versioning summary (from `ROADMAP.md` §1)

- v0.1 = Stage 1 exit (HEALTH to Whoop/Oura + AI)
- v0.2 = Stage 2 exit (Archive + 事件计划 + quest completion ceremony)
- v0.3 = Stage 3 exit (Ingest + 记账 + 4 cross-domain triggers visible)
- **v1.0-personal** = Stage 4 exit (all 5 tabs real + dopamine loop wired)
- v1.0 (public) = post-Stage 4 polish (≥5 rules + 7-day daily-use validation)

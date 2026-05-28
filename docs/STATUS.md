# NeonSaga — Status (genesis)

**Snapshot date:** 2026-05-28
**Product source of truth:** `docs/PRODUCT.md`
**Roadmap source of truth:** `ROADMAP.md`
**规范 source of truth:** `CLAUDE.md`

## What ships today

No user-facing product yet. The genesis toolchain is wired: the
`NeonSagaCore` SwiftPM package builds, the custom test runner is seeded and
green, `make` targets resolve, and `make verify` passes on the empty
skeleton. No production feature code yet (Stage 1 begins that). The iOS app
and test targets are seeded empty — they go green once Stage 1 lands sources.

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
| `NeonSaga/Models/` | 0 |
| `NeonSaga/Services/` | 0 |
| `NeonSaga/Views/` | 0 |
| `NeonSagaTests/` | 0 |
| `docs/adr/` | 1 ADR + template (ADR-001 accepted) |

Updated after each Stage exit per `CLAUDE.md` §1.4.

## Verification state

- `make verify`: **green** — pre-commit hooks (swift-format lint + hygiene) +
  `make build-core` + `make test-core` (custom runner: `2 passed, 0 failed`).
- `make verify-full`: not yet green — iOS app/test targets are seeded empty
  (no `@main` entry point until Stage 1), so `make build` / `make test` do not
  yet pass. `make gen` succeeds.
- Latest iOS test count: N/A (`NeonSagaTests` empty until Stage 1)
- Latest screenshots: N/A — `docs/screenshots/` empty until Stage 1 ships

## Git state

- Branch: `main`, pushed to `origin` (github.com/kyriekevin/NeonSaga).
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

## Versioning summary (from `ROADMAP.md` §1)

- v0.1 = Stage 1 exit (HEALTH to Whoop/Oura + AI)
- v0.2 = Stage 2 exit (Archive + 事件计划 + quest completion ceremony)
- v0.3 = Stage 3 exit (Ingest + 记账 + 4 cross-domain triggers visible)
- **v1.0-personal** = Stage 4 exit (all 5 tabs real + dopamine loop wired)
- v1.0 (public) = post-Stage 4 polish (≥5 rules + 7-day daily-use validation)

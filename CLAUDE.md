# CLAUDE.md — NeonSaga 规范 (v2)

This file is the shared agent contract for Claude Code and Codex working in
the NeonSaga repository. Keep one source of truth here. `AGENTS.md` is a
compatibility symlink to this file.

> **Read first:** `docs/ROADMAP.md` (4-stage plan, locked) and
> `docs/PRODUCT.md` (product vision, locked). All work defers to these two
> documents.

NeonSaga is a personal-use iOS RPG character sheet. The §1 strict 规范
below codifies the discipline required to keep the codebase coherent under
autonomous-agent execution — the friction is intentional.

---

## 1. Strict 规范 — non-negotiable for the 8-week run

These rules are hard rules. Violations block PR merge. See `docs/ROADMAP.md`
§6 for the rationale per rule.

### 1.1 Spec-first CONTRACT gate

Every PR begins with `CONTRACT.md` in a worktree. The CONTRACT is a process
artifact — NOT committed to the PR. Use `docs/templates/CONTRACT.md` as the
starting template. Required fields:

- Goal (1 sentence, user-visible outcome)
- Scope (committed) + Out of scope
- Architecture / interfaces touched
- Required behavior (user-visible)
- **Failing tests defining "done"** (TDD red phase, listed by test name)
- **Source references** (§1.5)
- Open questions
- Plan B cut order (when stage has a deadline)

**Worker subagents cannot write production code until the CONTRACT has been
Codex-reviewed AND lead-approved.** This is the first review (of the
contract). The second review is of the worker's diff after implementation.

### 1.2 TDD red + green discipline (PR-level)

PR-level enforcement, not pre-commit ancestry hook (brittle for autonomous
agents).

- Each PR contains a "red" commit (failing test only) prefixed `red:` and a
  "green" commit (implementation that makes the test pass) prefixed `green:`.
- The implementation commit must not modify the test file. If the test needs
  fixing, amend back to a new red commit and re-green.
- Reviewer verifies discipline via `git log --oneline` prefix grep.

**Scope:** Applies to production-code PRs (any change touching
`NeonSagaCore/Sources/` or `NeonSaga/`). Exempt from `red:`/`green:` commit
discipline: docs-only PRs (`*.md`), pure config (`project.yml`, `Makefile`,
`Package.swift`, `.entitlements`, `Info.plist`), pure assets
(`Assets.xcassets/`), generated boilerplate (XcodeGen output), and the
**one-time genesis bootstrap** — the custom test-runner harness in
`NeonSagaCoreTests/main.swift`, the minimal `@main` app shell, and the SwiftPM /
XcodeGen skeleton (the runner cannot be test-driven before it exists, and a
feature-less shell has no behavior to assert; the first real `red:`/`green:`
pair lands with the first Stage 1 feature). Bugfixes
are NEVER exempt — write a reproducing test first. When in doubt → TDD. The
TDD skill (`.claude/skills/tdd/SKILL.md`) enumerates the same exemptions.

Pure Swift logic → `NeonSagaCore/Sources/NeonSagaCoreTests/main.swift`,
verify with `make test-core`. SwiftUI/SwiftData → `NeonSagaTests/` (iOS
XCTest), verify with `make test`. The owner does not read Swift fluently —
tests are the primary correctness signal. After running tests, always
report the pass/fail summary line (`N passed, M failed`).

### 1.3 Scope freeze + ADR

- `docs/ROADMAP.md` is the only authority on what ships in v1.0-personal.
- Any feature not in the ROADMAP is rejected by default.
- To add a feature mid-stage: write an ADR under `docs/adr/NNN-<slug>.md`
  using `docs/adr/000-template.md`. The ADR is Codex-reviewed before any
  code change.
- ADRs cost 30–60 minutes of writing. Friction is intentional.

### 1.4 Per-stage exit ritual

Each Stage closes with this ritual, in order:

1. `make verify-full` green.
2. Updated screenshots in `docs/screenshots/` for shipped surfaces.
3. Owner installs dev build on real iPhone for the stage's exit-duration:
   - Stage 1 (v0.1): ≥1 day
   - Stage 2 (v0.2): ≥1 day
   - Stage 3 (v0.3): ≥3 days (killer-edge dwell test)
   - Stage 4 (v1.0-personal): ≥1 day, must complete 5-tab happy-path smoke flow
     (CORE → INGEST log → ORACLE ask → CONTRACTS view → ARCHIVE scrub)
   - v1.0 public (post-Stage 4): ≥7 days
4. `docs/STATUS.md` updated to reflect shipped state.
5. Wiring completeness checklist (§1.7) all green.
6. `git tag <stage version>` (annotated, signed if GPG available). Versions
   are `v0.1` / `v0.2` / `v0.3` / `v1.0-personal` per `docs/ROADMAP.md` §1.
7. Push tag to origin.

### 1.5 External code import discipline + source references

When a CONTRACT introduces production code from any external source (prior-art
codebases, sample code, dependencies), the CONTRACT's "Source references"
section must list:

- Source identifier (path, URL, or library)
- Files copied (source path → NeonSaga path)
- Module rename points (e.g., `OldModule` → `NeonSagaCore` across imports,
  `Package.swift`, `project.yml`, custom test runner registration in
  `NeonSagaCoreTests/main.swift`)
- SwiftData `@Model` container schema entries added
- Asset references and screenshot paths
- License / attribution if applicable
- Reason for importing vs. writing fresh

When external code is brought in, it's reviewed for fit against the new
CONTRACT. If it doesn't fit cleanly: rewrite, don't patch.

### 1.6 Autonomous agent readiness

For tasks issued to autonomous agents (Goal, Claude Code worker, Codex
worker):

- Task granularity ≤ 1 sub-feature. Multi-day tasks split before dispatch.
- Every task done-criterion uses the **verification matrix** (§1.9), not
  blanket `make verify`.
- Workers cannot trigger external reviews (only lead / owner dispatches
  Codex / Gemini review).

### 1.7 Wiring completeness — no orphaned layers

Each stage exit requires the wiring completeness checklist all green. For
the stage's CONTRACTs, verify:

- [ ] All shipped tabs reachable from `RootTab.allCases` / `RootView`
- [ ] `project.yml` updated for new files; `make gen` produces clean diff
- [ ] All new `@Model` classes added to `NeonSagaApp.swift` ModelContainer schema
- [ ] All new core tests registered in `NeonSagaCoreTests/main.swift` (custom
  runner does NOT auto-discover)
- [ ] All new iOS XCTest files included in `NeonSagaTests/` target via `project.yml`
- [ ] Screenshots updated in `docs/screenshots/` for any visual change
- [ ] All new system capabilities (HealthKit, camera, photo library, location, CloudKit, network) declared in `project.yml` entitlements + matching usage-string keys in `Info.plist` (`NSHealthShareUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, etc.); permission flow verified in simulator and on device
- [ ] `docs/STATUS.md` reflects new shipped state, file counts, verification result
- [ ] No placeholder views left behind for surfaces this stage shipped real
- [ ] No dead routes / unreachable code
- [ ] All external imports declared in their CONTRACT's "Source references" (§1.5)

If any checkbox is unchecked at stage exit, the stage is not closed.

### 1.8 Spec hierarchy precedence

When two specs conflict, the higher-precedence spec wins until an ADR
explicitly supersedes:

| Rank | Spec | Owns |
|---|---|---|
| 1 | `docs/PRODUCT.md` | Product identity, IS / IS NOT, privacy boundary, dopamine hooks, sub-stat sources |
| 2 | `docs/ROADMAP.md` | Stage scope, stage order, what ships in v1.0-personal vs v1.x |
| 2.5 | `docs/SCHEDULE.md` | Dates, weeks, DDLs (derived from ROADMAP §1 but **authoritative** for date / DDL / week-mapping questions) |
| 3 | Stage `CONTRACT.md` (worktree-local) | Exact files, exact interfaces, exact tests for one slice |
| 4 | `docs/ui/*.md` | Visual behavior, layout specifics |
| ★ override | `docs/adr/NNN-*.md` | Overrides any spec by explicit decision + Codex review (per §1.3); ADRs sit on the side, not in the rank table — they supersede |

**Contradiction stop rule:** If an agent encounters a contradiction between
specs (e.g., ROADMAP says X but PRODUCT says not-X), it must stop and either
(a) write an ADR resolving the conflict, or (b) escalate to the lead.
Implementing one side and ignoring the other is forbidden — that creates
incoherent layers, which is the failure mode this 规范 exists to prevent.

### 1.9 Verification matrix

Different changes require different verification. `make verify` alone is
insufficient for SwiftUI/SwiftData regressions.

| Change scope | Verification command | Reason |
|---|---|---|
| Pure Swift logic in `NeonSagaCore` (algorithms, parsers, rules) | `make test-core` | Sub-second; custom runner covers this layer |
| SwiftData `@Model` or SwiftUI views | `make test` (iOS XCTest) | `test-core` cannot host SwiftData/SwiftUI |
| Anything that crosses `NeonSagaCore` ↔ `NeonSaga/` boundary | `make verify-full` | Catches schema + view + service integration |
| Docs-only change (`*.md`, no code) | Proofread + spec hierarchy check (§1.8); no `make` needed | No build artifact to verify |
| Build config (`project.yml`, `Makefile`, `Package.swift`) | `make gen` clean diff + `make build-core` + `make build` | Catches missing-file / target / dependency regression |
| Asset addition (`Assets.xcassets/`, images, icons) | `make build` + visual check in simulator | Catches missing-asset / wrong-bundle errors |
| Skill change (`.claude/skills/*/SKILL.md`) | Manual review; SKILL.md trigger self-test on a sample task | Skills are documentation, not code |
| Pre-commit hook / CI workflow change | Run hook on a test file; CI dry-run | Catches policy violations early |
| Stage exit (any stage) | `make verify-full` + simulator screenshot + iPhone install | Per §1.4 |
| Autonomous-agent task done-claim | The matrix row matching the task's scope; not blanket `make verify` | Per §1.6 |

If a task's scope is ambiguous (touches both core and views), use the broader
command — when in doubt, `make verify-full`.

**Genesis bootstrap clause:** until the first Stage 1 feature lands, the hard
bar is `make verify` (hooks + `build-core` + `test-core`). The minimal `@main`
shell keeps `make build` / `make test` / `make verify-full` green too, but
feature-level build/test verification is first meaningfully exercised from
Stage 1 (a feature-less app has no behavior to assert). See §1.2's genesis
bootstrap exemption.

---

## 2. Common commands

All builds and tests are driven by `make`. Xcode project is generated from
`project.yml` (XcodeGen) — never edit `NeonSaga.xcodeproj` by hand; add
files on the filesystem then `make gen`.

| Command | Purpose |
|---|---|
| `make verify` | Hooks + `make build-core` + `make test-core` |
| `make verify-full` | `make verify` + `make gen` + iOS build + iOS test |
| `make test-core` | NeonSagaCore custom-runner tests (sub-second) |
| `make build-core` | `swift build` inside `NeonSagaCore/` |
| `make test` | `xcodebuild test` — `NeonSagaTests` bundle |
| `make build` | `xcodebuild` for iPhone 17 simulator |
| `make gen` | Regenerate `NeonSaga.xcodeproj` |
| `make open` | Gen + open in Xcode |
| `make clean` | Remove generated project + DerivedData |

There is no "run a single test" command for `NeonSagaCore` — the custom
runner executes the whole file. To narrow scope, temporarily comment out
unrelated `group(...)` sections in
`NeonSagaCore/Sources/NeonSagaCoreTests/main.swift`.

---

## 3. Architecture (two-layer split)

- **`NeonSagaCore/`** — pure Swift package. No SwiftUI / SwiftData / UIKit /
  HealthKit / CoreLocation. Algorithms, protocols, enums, AI service stubs.
  Testable on CLT alone (custom runner — see §4).
- **`NeonSaga/`** — iOS app target. SwiftUI views, SwiftData `@Model` classes,
  HealthKit reader, location services. Imports `NeonSagaCore`.
- **`NeonSagaTests/`** — iOS XCTest bundle for `@Model` and SwiftUI tests.

This split is load-bearing. Anything testable on CLT belongs in
`NeonSagaCore`. A `HealthDataSource` protocol lives in core; the real
`HKHealthStore`-backed implementation lives in `NeonSaga/Services/`.

---

## 4. Toolchain quirks

- **`NeonSagaCoreTests` is `.executableTarget`, NOT XCTest.** Apple's CLT
  ships incomplete XCTest/Testing frameworks (missing
  `lib_TestingInterop.dylib`). The custom runner in
  `NeonSagaCoreTests/main.swift` uses `group(...)` / `expect(...)` /
  `expectAsync(...)` helpers, top-level code, `@MainActor` on helpers.
  Exits non-zero on first failure. To narrow scope, comment out unrelated
  `group(...)` sections temporarily.
- **`SWIFT_STRICT_CONCURRENCY: targeted`** in `project.yml`, not `complete`.
  `@Model` classes are non-Sendable per Apple; `complete` floods warnings
  when models cross actor boundaries.

---

## 5. SwiftData + CloudKit rules

Bind every `@Model` class in `NeonSaga/Models/`:

- ❌ No `@Attribute(.unique)` — CloudKit private DB rejects unique constraints.
- ❌ No non-optional, non-defaulted stored properties.
- ❌ No non-optional relationships — must be optional with explicit `inverse:`.
- ✅ Enforce uniqueness at insert site (FetchDescriptor → update/insert).

CloudKit dormant: `cloudKitDatabase: .none` until paid Apple Developer
account upgrade. Entitlements pre-declared so the flip is one line.

---

## 6. Agent workflow (lead/worker)

Claude Code: main agent = Claude Opus 4.7; workers = Claude Sonnet 4.6.
Codex: main agent = GPT-5.5 xhigh; workers = GPT-5.4-mini medium for narrow
implementation, GPT-5.3-Codex-Spark for trivial / search, GPT-5.4 high for
complex cross-module SwiftData / SwiftUI state / concurrency.

The main agent owns: planning, tests, decisions, integration, verification,
PR hygiene. Workers own: implementation in isolated worktrees and
review-fix iteration. Workers may NOT trigger external reviews — only lead
or owner dispatches Codex (Claude Code flow) or Gemini (Codex flow).

### Per-feature phased pipeline

| Phase | Artifact | Reviewer |
|---|---|---|
| 1 — Owner brief | 1-page product spec (behavior, IS / IS-NOT, verification) | Owner |
| 1b-contract | `CONTRACT.md` in worktree (see §1.1) | Codex (contract only) |
| 1b-tests | Failing RED tests against contract | Codex (tests only) |
| 2 — Worker impl | Worker turns RED → GREEN | — |
| 2b | Worker diff | Codex (diff vs contract) |
| 3 — Verify | `make verify-full` + iPhone install per §1.4 | Lead |

Skip the pipeline only for changes under ~30 LOC with no architectural
decisions (typos, dead-code removal, mechanical renames).

**Lead does not do substantive content review on worker output.** Post-worker
check is mechanical: file scope, hard constraints (`AGENTS.md` symlink,
`make verify` green), `git status` sanity. If those pass, hand to reviewer.

---

## 7. Secrets

Never commit real API keys. Provider keys go through `APIKeyStore`
(to be built in NeonSagaCore). Tests use fake strings only. `.env` ignored.

---

## 8. Repo hygiene

Run `make install-hooks` once per clone so `git commit` runs the pre-commit
gate locally (the committed `.pre-commit-config.yaml` does NOT auto-install).
The gate (swift-format lint `--strict` + the §3/§5 guards in
`scripts/precommit/` + hygiene) is authoritative — verify lint via `make hooks`
/ `make verify`, never a `git status`-derived file list. `swift format lint`
WITHOUT `--strict` only warns and exits 0 (a false-green trap).

Before pushing:

```bash
git status --short --branch
git status --ignored --short
make verify
```

Push to feature branches only — never directly to `main`. Commit
`.claude/settings.json` for shared agent setup; do not commit
`.claude/settings.local.json` (machine-specific, gitignored).

---

## 9. Tracked top-level skills

Claude project skills live in `.claude/skills/`. Codex project skills live
in `.agents/skills/` as symlinks to the same directories. Discover via
`.claude/skills/*/SKILL.md` (Claude) or `.agents/skills/*/SKILL.md` (Codex).
Do not recurse into nested packaged skill copies unless the top-level skill
requires it.

The following skills are mandatory once their domain enters scope (typically
during Stage 1):

- `slice-pipeline` — the executable runbook for the §6 phased pipeline (CONTRACT
  → reviews → red/green → verify → PR → retro). Use it whenever running a slice
  or opening a PR.
- `tdd` — enforces red/green/refactor on every change (§1.2)
- `swiftui-pro`, `swiftui-design-principles`, `swiftui-ui-patterns`,
  `swiftui-view-refactor` — for SwiftUI work
- `swiftdata-pro` — for `@Model` work
- `swift-concurrency-pro` — for async/await review
- `ios-simulator-skill` — for iOS automation and screenshots

Project subagents live in `.claude/agents/`: `neonsaga-green-worker` (Sonnet)
carries the standing GREEN-phase worker context so phase-2 dispatch needs only
the per-slice delta.

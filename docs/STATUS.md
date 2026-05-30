# NeonSaga — Status (Stage 1 in progress)

**Snapshot date:** 2026-05-31
**Product source of truth:** `docs/PRODUCT.md`
**Roadmap source of truth:** `docs/ROADMAP.md`
**规范 source of truth:** `CLAUDE.md`

> **Update cadence note.** `CLAUDE.md` §1.4 mandates a STATUS update at each
> *stage exit*. Because a stage runs for weeks, this file is also refreshed
> mid-stage after notable slices so it never misrepresents shipped state; the
> full §1.4 exit ritual still runs at the `v0.1` tag.

## What ships today

Stage 1 (HEALTH domain) is in progress. Slices **S1–S7 (incl. S6b) are merged**,
with the agent-infra sprint (PRs #14–#17: pre-commit hooks, slice-pipeline
skill + green-worker, ADR-003 UI-eval, ADR-004 supply-chain) in between. `main` is
at `6017791`; **S8 (Sleep architecture detail) is this PR**. What is real and tested:

- **HEALTH core** (`NeonSagaCore`, pure Swift): per-value LV math (`Level`,
  `SubStat`, `SubStatValue`, `HealthStat`, `LevelUp`), `HealthMetrics` +
  `HealthSnapshot.derive` (raw signals → HUNGER/FATIGUE/STRENGTH sub-stats),
  `HealthDataSource` protocol, **Recovery** score 0–100 + RED/YELLOW/GREEN
  bands, **Strain** score 0–21, shared `Comparable.clamped(to:)`,
  **time-aware EWMA sub-stat accumulation** (`EWMA` / `HealthAccumulation` /
  `DailyHealthInput`; ADR-002, S6b), **level-up crossing detection**
  (`LevelUp.detectCrossings` + `SubStatLevelCrossing`, S7), and **sleep
  architecture** (`Sleep.summary` → `SleepResult` / `SleepSummary`, S8).
- **App persistence** (`NeonSaga/`): `HealthSnapshotRecord` `@Model`
  (CloudKit-dormant, `cloudKitDatabase: .none`) + `@MainActor`
  `HealthSnapshotStore` (save / latest / `deriveAndStore` + suffix re-accumulate /
  28-day `recentHRVBaseline`).
- **HEALTH detail surface**: `HealthDetailView` / `HealthDetailViewModel` /
  `HealthDetailAdapter` — a dark Cyberpunk-HUD 4-card stack (Recovery ring,
  **Sleep architecture**, Strain bar, HEALTH sub-stats).
- **Level-up takeover** (S7): `LevelUpTakeoverView` — a full-screen Cyberpunk-HUD
  overlay (~0.8s scale/opacity intro + `.sensoryFeedback` success haptic) that
  fires when any HEALTH sub-stat crosses an LV threshold upward. The
  `HealthDetailViewModel` detects crossings by diffing the previously-displayed
  vs. freshly computed sub-stat values and queues them FIFO (silent on first
  load). Sound asset + glitch motion-polish are deferred (ROADMAP Plan B L4 / S11).
- **Sleep architecture** (S8): the Sleep card renders Deep/REM/Light minutes, a
  proportional stacked bar, the asleep total, time-in-bed + efficiency, and wake
  events — driven by a pure-core `Sleep.summary(for:)` (`.noData` / `.scored`)
  that reads only five new raw sleep-stage fields on `HealthMetrics`
  (`deepSleepMinutes` / `remSleepMinutes` / `lightSleepMinutes` /
  `timeInBedMinutes` / `wakeEventsCount`), persisted on `HealthSnapshotRecord`.
  Fed synthetic / in-memory data until the S5b HealthKit reader lands;
  time-in-bed + wake events are independently optional (ROADMAP Plan B L3).

**Two caveats a reader must know:**

1. **`HealthDetailView` is the *temporary* app root**, not the permanent
   PRODUCT §10 CORE first-eye character sheet. The full 5-tab IA
   (CORE/INGEST/ORACLE/CONTRACTS/ARCHIVE) and the permanent CORE sheet are not
   built yet. Note, though, that Stage 1 **does** already require a CORE
   surface: ROADMAP §2 item 8 puts the daily streak counter "in the CORE
   first-eye header" and repeats it in the exit criteria — so **S10 must
   resolve CORE/root placement** (a `RootView`/`RootTab` shell is still owed).
2. **No real HealthKit data yet.** The `HKHealthStore`-backed reader is
   deferred to **S5b** (on-device, gated on entitlement + Info.plist usage
   string). Until S5b runs on a physical iPhone, Recovery/Strain/sub-stats
   are exercised only against synthetic / in-memory data — the Stage 1 exit
   criterion "values derived from real HealthKit samples" depends on S5b
   landing *before* the `v0.1` tag.

## What's next

Remaining Stage 1 slices (per `docs/ROADMAP.md` §2): **S9** AI Recovery brief,
**S10** Daily streak counter, **S11** visual subjective parity polish +
screenshots. Plus **S5b** (device HealthKit reader) —
must land before the `v0.1` exit ritual so real data backs the scores (and so the
S7 takeover live-fires on real LV crossings, not just synthetic test data). Each
slice runs the
`CLAUDE.md` §6 phased pipeline (CONTRACT → RED tests → worker GREEN → Codex
diff review → `make verify-full` → PR → owner merge).

See `docs/ROADMAP.md` §2 for full Stage 1 scope and Plan B cut order.

## File counts (S8)

| Surface | Files |
|---|---|
| `NeonSagaCore/Sources/NeonSagaCore/` | 15 (`NeonSagaCore.swift`, `Comparable+Clamped.swift`, + `Health/` (13): `Level`, `SubStat`, `HealthStat`, `LevelUp`, `HealthMetrics`, `HealthSnapshot`, `HealthDataSource`, `Recovery`, `Strain`, `DailyHealthInput`, `EWMA`, `HealthAccumulation`, `Sleep`) |
| `NeonSagaCore/Sources/NeonSagaCoreTests/` | 1 (`main.swift` — custom runner; 202 assertions) |
| `NeonSaga/App/` | 1 (`NeonSagaApp.swift` — `@main`, temporary HEALTH-detail root) |
| `NeonSaga/Models/` | 1 (`HealthSnapshotRecord.swift`) |
| `NeonSaga/Services/` | 2 (`HealthSnapshotStore.swift`, `HealthDetailAdapter.swift`) |
| `NeonSaga/ViewModels/` | 1 (`HealthDetailViewModel.swift`) |
| `NeonSaga/Views/` | 2 (`HealthDetailView.swift` (now incl. the Sleep architecture card), `LevelUpTakeoverView.swift`) |
| `NeonSagaTests/` | 8 (`GenesisSmokeTests`, `HealthSnapshotStoreTests`, `HealthSnapshotStoreBaselineTests`, `HealthAccumulationStoreTests`, `HealthDetailViewModelTests`, `LevelUpViewModelTests`, `SleepViewModelTests`, `SleepDurationTextTests`) |
| `docs/adr/` | 4 ADRs + template (ADR-001…004 accepted) |

Refreshed after notable slices; full file-count audit re-confirmed at each
Stage exit per `CLAUDE.md` §1.4.

## Verification state

- `make verify`: **green** — pre-commit hooks (swift-format lint + hygiene) +
  `make build-core` + `make test-core` (custom runner: `202 passed, 0 failed`).
- `make verify-full`: **green** (2026-05-31) — `make verify` + `make gen` +
  iOS `make build` + iOS `make test` on the iPhone 17 simulator:
  **202 core / 52 iOS, 0 failed**.
- Latest iOS test count: 52 across 8 suites (`GenesisSmokeTests`,
  `HealthSnapshotStoreTests`, `HealthSnapshotStoreBaselineTests`,
  `HealthAccumulationStoreTests`, `HealthDetailViewModelTests`,
  `LevelUpViewModelTests`, `SleepViewModelTests` (5, S8),
  `SleepDurationTextTests` (2, S8))
- Latest screenshots: none committed — `docs/screenshots/` holds only
  `.gitkeep`; the HEALTH-detail screenshot lands with S11 (visual parity)
  per `CLAUDE.md` §1.4 stage-exit ritual.

## Git state

- Default branch: `main` — protected (PRs required before merge; force-push +
  deletion blocked; enforced for admins too).
- Workflow: all changes land via feature branch → PR → Codex review → merge
  (`CLAUDE.md` §8). Genesis specs + ADR-001 are the root commit (`3b098d4`);
  slices S1–S6 + S6b landed via PRs #2–#13, the agent-infra sprint via PRs
  #14–#17 (hooks, slice-pipeline skill, ADR-003, ADR-004), and S7 via PR #18,
  all squash-merged; `main` now at `6017791`. S8 (this PR) is the next slice.
- Tags: none (first tag `v0.1` at Stage 1 exit).

## Genesis tasks (completed — history)

These were the pre-Stage-1 setup tasks; all are done (the first Stage 1
CONTRACT started long ago — S1–S6 are merged). Kept here as history rather
than in `ROADMAP.md` to keep the ROADMAP focused on product stages.

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

# SCHEDULE — NeonSaga 8-week run

> Source of truth for dates and deadlines. Derived from `ROADMAP.md` §1
> versioning + per-stage targets in §2–§5. Update at each stage exit.
> Hard rule: see `CLAUDE.md` §1.4 per-stage exit ritual.

---

## Calendar overview

| Week | Date range | Stage | Milestone | Status |
|---|---|---|---|---|
| 0 | 2026-05-27 → 2026-05-28 | Genesis | 规范 docs locked + git init + Makefile/project.yml wired + skill ports + skeleton green | In progress |
| 1 | 2026-05-29 → 2026-06-04 | Stage 1 W1 | Stage 1 CONTRACT + RED tests; HealthDataSource + HealthSnapshot skeleton; Recovery skeleton | Pending |
| 2 | 2026-06-05 → 2026-06-11 | Stage 1 W2 | Strain + Sleep architecture; AI Recovery brief wired; **Day-13 spike go/no-go** | Pending |
| 3 | 2026-06-12 → 2026-06-17 | Stage 1 W3 (close) | Visual polish; Level-up takeover; **v0.1 ship** | Pending |
| 4 | 2026-06-18 → 2026-06-24 | Stage 2 W1 | Stage 2 CONTRACT; Archive 3-section + Quest Design Day flow | Pending |
| 5 | 2026-06-25 → 2026-06-28 | Stage 2 W2 (half, close) | Quest completion ceremony; **v0.2 ship** | Pending |
| 6 | 2026-06-29 → 2026-07-05 | Stage 3 W1 | Stage 3 CONTRACT; Transaction model + Ingest tab + LOG TRANSACTION sheet | Pending |
| 7 | 2026-07-06 → 2026-07-12 | Stage 3 W2 (close) | LOG MEAL + WEALTH detail + 4 cross-domain triggers; **v0.3 ship** | Pending |
| 8 | 2026-07-13 → 2026-07-22 | Stage 4 (1.5 wks) | Stability + Contracts + Oracle + Milestones + GROWTH + TestFlight; **v1.0-personal ship** | Pending |
| 9+ | 2026-07-23+ | Post-Stage 4 | 7-day daily-use validation; 5th cross-domain rule; **v1.0 public** | Pending |

---

## Critical DDLs

| DDL | What | Cascade if missed |
|---|---|---|
| **2026-06-04** (Stage 1 W1 end) | Recovery score skeleton in (even placeholder math) | Stage 1 slip risk real; Plan B starts cutting from bottom |
| **2026-06-10** (Stage 1 Day 13) | Killer-edge spike go/no-go gate | Spike skipped → killer-edge validation moves to Stage 3 Day 0 |
| **2026-06-17** (Stage 1 deadline) | v0.1 git tag cut | Stage 2-4 timeline cascades; Stage 4 risks slip-into-August |
| **2026-06-28** (Stage 2 deadline) | v0.2 git tag cut | Quest system unfinished entering Stage 3 |
| **2026-07-12** (Stage 3 deadline) | v0.3 git tag cut | Cross-domain "killer-edge" not validated entering Stage 4 |
| **2026-07-22** (Stage 4 deadline) | v1.0-personal git tag cut | 8-week run misses; v1.0 public timeline collapses |
| **2026-07-29** (W +1 after v1.0-personal) | Daily-use validation window end (if started Day 1) | Public v1.0 not achievable without 7-day use validation |

---

## Per-stage exit checklist (per `CLAUDE.md` §1.4)

For each stage exit, all six must be true:

1. [ ] `make verify-full` green
2. [ ] Screenshots updated in `docs/screenshots/`
3. [ ] Owner installed on iPhone; usage window completed per `ROADMAP.md` §1 hard rule
4. [ ] `docs/STATUS.md` updated
5. [ ] Wiring completeness all green (CLAUDE §1.7); CONTRACT "Source references" (§1.5) filled for any external imports
6. [ ] `git tag <stage version>` + push

---

## Buffer policy

- **No buffer week.** Plan B cut order per stage absorbs slippage.
- If two consecutive stages slip the deadline, lead **must** write a
  "scope reduction ADR" before Stage 4 starts, cutting Stage 4 scope in
  this order: Demo video → TestFlight build (dev build acceptable, since
  TestFlight is post-feature) → GROWTH detail → Contracts visual redesign
  refinement (basic Contracts works either way).
- **Never cut from Stage 4:** Oracle (5-tab promise per `ROADMAP.md` §5),
  Milestone toasts (PRODUCT §3.2 dopamine hook), Quest completion ceremony
  (PRODUCT §3.4 dopamine hook, shipped in Stage 2 but referenced again in
  Stage 4 polish).
- v1.0-personal deadline can move to **2026-07-29** (1 week extension)
  **only** via owner ADR; no agent-discretion extension.

---

## Tracking conventions

Status column values: `Pending` / `In progress` / `Done` / `Cut (ADR-NNN)` / `Slipped to <date>`.

Lead updates this table:
- Each Monday morning (week start) — refresh current week status
- Each stage exit — flip the milestone to `Done`, advance the next stage to `In progress`

---

## Source & history

- v3 published 2026-05-27 alongside `ROADMAP.md` v3.
- Calendar week granularity per `ROADMAP.md` §1 versioning.
- Critical DDLs derived from `ROADMAP.md` §2–§5 targets + Codex v2 #2 Day-13 gate.
- Buffer policy from `ROADMAP.md` §0 + lead discretion.

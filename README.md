# NeonSaga

Personal-use iOS RPG character sheet, built under strict 规范.

> **Stage 1 in progress (HEALTH domain).** Slices S1–S6 are merged: the
> pure-Swift HEALTH core (LV math, `HealthSnapshot`, Recovery 0–100, Strain
> 0–21), SwiftData persistence (`HealthSnapshotRecord` + `HealthSnapshotStore`),
> and an installable HEALTH detail surface. `make verify-full` is green
> (135 core / 23 iOS tests). No real HealthKit data yet — the
> `HKHealthStore`-backed reader is deferred to S5b (on-device); scoring runs
> on synthetic/in-memory data until then. See
> [`docs/STATUS.md`](docs/STATUS.md) for the shipped state and
> [`docs/ROADMAP.md`](docs/ROADMAP.md) for the 4-stage plan.

## Where to start

- [`docs/PRODUCT.md`](docs/PRODUCT.md) — product vision (locked)
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — 4-stage plan (locked after 7-pass Codex review)
- [`docs/SCHEDULE.md`](docs/SCHEDULE.md) — week-by-week dates + critical DDLs
- [`CLAUDE.md`](CLAUDE.md) — 规范 for agents (Claude + Codex) working here
- [`docs/STATUS.md`](docs/STATUS.md) — current shipped state

## Process templates

- [`docs/templates/CONTRACT.md`](docs/templates/CONTRACT.md) — stage / feature CONTRACT (process artifact, not committed to PR)
- [`docs/adr/000-template.md`](docs/adr/000-template.md) — Architectural Decision Record

## Quick commands

```bash
make verify          # Hooks + core build + core tests (CLT-only)
make verify-full     # + iOS build + iOS tests
make test-core       # Just core tests (sub-second)
make test            # Just iOS tests
make gen             # Regenerate Xcode project from project.yml
make open            # Gen + open in Xcode
```

## Project philosophy

NeonSaga is a strict-规范 build for an 8-week run to a personally-complete
`v1.0-personal` release, targeting TestFlight (or dev build if Apple
Developer account is not yet upgraded) by ~2026-07-22. Public `v1.0` is
reserved for post-Stage 4 polish (≥5 cross-domain rules + 7-day daily-use
validation).

The strict 规范 in [`CLAUDE.md`](CLAUDE.md) §1 (spec-first CONTRACT gate,
TDD red+green, scope freeze + ADR, per-stage exit ritual, wiring
completeness, spec hierarchy precedence, verification matrix) exists to
keep the codebase coherent under autonomous-agent execution — the friction
is intentional.

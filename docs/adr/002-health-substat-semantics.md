# ADR-002 — HEALTH sub-stat semantics: sources + dynamics

> Architectural Decision Record. Required by `CLAUDE.md` §1.3 because it (a)
> resolves a contradiction between two locked specs (PRODUCT §9 vs ROADMAP §2
> item 9, per the §1.8 contradiction-stop rule) and (b) adds a stat-dynamics
> model not in the locked ROADMAP. Reviewed by Codex before any code change.

---

## Status

proposed

## Date

2026-05-29

## Context

Slices S1–S6 shipped the HEALTH core + the HEALTH detail surface. Reading the
shipped code against the locked specs surfaced two problems that both block
S7 (Level-up takeover), which fires when a HEALTH sub-stat crosses an LV
threshold.

**Problem 1 — FATIGUE source: the two locked specs contradict each other.**
- `docs/PRODUCT.md` §9 (rank 1) lists the FATIGUE sub-stat source as
  **HRV from Apple Health, fully automatic** — a single source.
- `docs/ROADMAP.md` §2 item 9 (rank 2) says **"HKWorkout → STRENGTH and
  FATIGUE; sleep samples → FATIGUE; HRV → FATIGUE / Recovery"** — three
  sources blended.
- The shipped code (`NeonSagaCore/.../HealthSnapshot.swift` `derive`) follows
  ROADMAP: `fatigue = mean(normHRV, normSleep, normWk)`.

Per `CLAUDE.md` §1.8, PRODUCT outranks ROADMAP, and the contradiction-stop
rule forbids silently implementing one side — it requires an ADR. The shipped
code silently implemented the lower-precedence spec; this ADR resolves it.
A second reason the blend is wrong on its own merits: the **Recovery hero
score already = HRV + RHR + sleep** (`Recovery.swift`, weights 0.5/0.25/0.25),
so a FATIGUE sub-stat that also blends HRV+sleep+workout largely duplicates
Recovery, and double-uses workout energy (which also drives STRENGTH).

**Problem 2 — sub-stat values are instantaneous, with no accumulation; this
makes S7 meaningless.** `derive` sets `strength = normWk ?? 0` (today's
workout energy ÷ 6, clamped 0–100) and recomputes every snapshot from that
snapshot alone. So STRENGTH is **0 (LV 1) on any rest day** and **~100 (LV
100) on a hard-workout day**, oscillating 0↔100 daily. `LevelUp.detect`
across consecutive snapshots would then fire takeovers constantly and
meaninglessly. The RPG framing (PRODUCT §1/§3 — "watch your character's
stats rise") requires stats that *accumulate*, not instantaneous readings.
The ROADMAP never specified a stat-dynamics model, so this is an additive
decision requiring an ADR.

Owner direction (2026-05-29 session): FATIGUE should be **consistent with
Whoop/Oura**; sub-stats should **accumulate with slow decay**. Research into
Whoop Recovery (HRV-dominant — one published breakdown cites ≈70% HRV / 20%
RHR / 10% sleep — baseline-relative) and Oura Readiness (RHR +
HRV-balance-vs-baseline + body-temp + sleep + activity) indicates both are
**HRV-vs-personal-baseline recovery composites, refreshed daily**. NeonSaga's
Recovery hero score is already that composite, mapped to the signals the owner
actually has (Apple Watch HRV rMSSD / RHR / sleep; no body-temp or reliable
SpO2 — see PRODUCT §9 / device notes). *(External sources, 2026-05: Whoop
Locker "How Recovery works" + Whoop developer "WHOOP 101"; Oura Help
"Readiness Contributors" + "Readiness Score". Exact vendor weights are
proprietary; the weighting figures above are illustrative of HRV dominance,
not load-bearing on this decision.)*

## Decision

Five sub-decisions. This ADR decides **semantics and architecture direction**;
exact function signatures, half-life constants, and the test list are
CONTRACT-level detail for the implementing slice.

1. **FATIGUE source = HRV only** (PRODUCT §9 wins). `derive` stops feeding
   sleep and workout energy into FATIGUE. Workout energy continues to drive
   STRENGTH only; sleep continues to feed the Recovery hero score only. This
   resolves the §1.8 contradiction by editing the lower-precedence spec
   (ROADMAP §2 item 9), not PRODUCT.

2. **HEALTH sub-stat values are accumulated with slow decay (EWMA), carried
   forward across snapshots** — not per-snapshot instantaneous readings.
   A pure-core EWMA primitive combines the previously-stored accumulated value
   with today's daily input:
   `accumulated = retention · previous + (1 − retention) · dailyInput`,
   where `retention ∈ (0,1)` derives from a per-stat half-life (Stage-1
   tunable constant). Cold start (no previous record) seeds
   `accumulated = dailyInput`.

3. **Daily inputs** feeding the EWMA:
   - **STRENGTH** ← normalized workout energy (metrics-only; today's load).
   - **FATIGUE** ← the **baseline-relative HRV recovery reading**, reusing the
     Recovery HRV-term (`clamp(50 + z·15, 0, 100)` against the rolling 28-day
     HRV baseline; neutral 50 while calibrating, i.e. <14 finite baseline
     samples or no finite today-HRV). This is the Whoop/Oura-consistent
     recovery axis the owner asked for.
   - **HUNGER** stays the neutral-50 placeholder until Stage 3 (photo →
     nutrition); accumulation applies once a real input exists.

4. **Recovery hero score stays unchanged** (daily readiness composite). The
   distinction is now clean and non-redundant: **Recovery = today's readiness
   (volatile, daily)**; **FATIGUE sub-stat = accumulated recovery *trend*
   (slow)**. The two can diverge meaningfully (a bad recovery today against a
   well-rested recent trend), which is informative rather than duplicative.

5. **S7 Level-up takeover fires on accumulated sub-stat LV crossings.** Because
   the accumulated values no longer oscillate, `LevelUp.detect` across stored
   records is now meaningful. STRENGTH and HUNGER (Stage 3) are the natural
   level-up drivers; FATIGUE crossings are also stable enough to surface.

**Architecture.** The EWMA math is a pure primitive in `NeonSagaCore`
(testable on the custom runner). Because accumulation needs the *previous*
stored value and (for FATIGUE) the HRV baseline at write time, the
accumulation step lives in the `@MainActor` store layer
(`NeonSaga/Services/HealthSnapshotStore.swift`), which already fetches
`latest()` and `recentHRVBaseline(before:)`. `HealthSnapshot.derive` is
refactored so its sub-stat outputs are understood as **today's daily inputs**
(instantaneous), while `HealthSnapshotRecord` stores the **accumulated**
values. The two-layer split (§3) is preserved: all new math is pure core; only
state/IO wiring is app-layer.

**Type boundary (required, per Codex 2b).** Once `derive`'s sub-stat outputs
are daily inputs, `HealthSnapshot.healthValue` / `healthLevel` (today they
aggregate the snapshot's sub-stats) would aggregate *daily inputs*, not the
accumulated character stats — so they must **not** drive the HEALTH display or
level-up detection. The CONTRACT must enforce this **structurally, at the
compiler level** (per Gemini): **drop `healthValue` + `healthLevel` from the
daily-input carrier, or rename the carrier entirely** (e.g. `DailyHealthInput`)
— documentation alone is insufficient to prevent accidental misuse, so the
"keep them + document loudly" escape hatch is rejected. Display +
`LevelUp.detect` read the **record's accumulated** values only (already how
`HealthDetailViewModel` computes HEALTH today — it reads `latest.*Value`, not
`snapshot.healthValue`). Do not leave two value surfaces that look
interchangeable.

**Write-path idempotence (required, per Codex 2a).** Accumulation makes the
write path order- and count-sensitive: today's `deriveAndStore` inserts a new
record on every call, so two calls in one day would double-accumulate. The
CONTRACT must implement **policy (a): upsert one record per stat-day and
re-derive the affected suffix on out-of-order / back-filled inputs** (per
Gemini). Policy (b) — rejecting duplicate-day / out-of-order / back-filled
inputs — is rejected: Apple Health back-fills and late-syncs sleep/workout
data as a matter of course, so rejecting would lose data or produce wrong
stats. Tests must cover duplicate `capturedAt`, same-day re-write, and
back-fill (with suffix re-derive).

**Explicitly NOT decided here:** the exact half-life constants (CONTRACT-level,
property-tested not pinned); renaming the FATIGUE/HUNGER sub-stats (see
Neutral/open); any change to Recovery, Strain, LV math, or the CORE-root work.

## Consequences

### Positive
- Removes a live §1.8 spec violation shipped in S2–S6 (FATIGUE source).
- FATIGUE becomes genuinely distinct from Recovery (trend vs state) and
  Whoop/Oura-consistent (baseline-relative HRV).
- STRENGTH becomes a real "fitness" character stat that rises with consistent
  training and decays gently on rest — the RPG "watch your stats grow" premise.
- Unblocks S7: level-up crossings are stable and meaningful, not daily noise.
- EWMA primitive is pure core → fully unit-testable without the simulator.

### Negative
- Reworks shipped, tested code: `derive`'s FATIGUE behavior changes
  (main.swift RB#5/#6/#7 "FATIGUE increases with sleep/workout" tests will be
  rewritten — expected, not a regression), and the store gains an
  accumulation path with new tests.
- Adds an implementation slice before S7 (see ROADMAP impact). Bounded, but it
  is added scope against a deadline-driven Stage 1.
- Accumulated values mean the stored sub-stat is **history-dependent**: it
  depends on the sequence of prior records, so back-filling or out-of-order
  inserts change results. The store must accumulate strictly in `capturedAt`
  order; the CONTRACT must test ordering + cold-start.

### Neutral / open
- **Refines the chat-level position.** In the 2026-05-29 discussion I proposed
  "FATIGUE = daily reading, not accumulated (only STRENGTH accumulates)." This
  ADR instead makes FATIGUE an **accumulated trend** of the daily recovery
  reading, because a non-accumulated FATIGUE = the HRV-term of Recovery
  (redundant), whereas an accumulated FATIGUE is distinct and matches the
  owner's "accumulate + slow decay" choice uniformly. Flagged for explicit
  owner sign-off (this is the main thing to confirm/reject at review).
- **Naming/polarity (non-blocking).** All three sub-stats are "higher = better"
  in code, but the words FATIGUE (high = tired?) and HUNGER (high = hungry?)
  read as the bad state. A rename (e.g. FATIGUE → RECOVERY/VITALITY, HUNGER →
  NOURISHMENT/SATIETY) would touch PRODUCT §6 sub-stat identity + the CLASS
  table; deferred to a possible follow-on ADR, not decided here.
- Half-life constants are guesses until the owner's real on-device HRV/workout
  data exists (S5b); starting hypotheses (NOT load-bearing): STRENGTH
  half-life ≈ 10–14 days (fitness builds slowly), FATIGUE ≈ 3–5 days (recovery
  trend turns faster). Revisit during the v0.1 iPhone usage window.

## Alternatives considered

- **Alt A — Keep the HRV+sleep+workout FATIGUE blend, edit PRODUCT §9 instead.**
  Rejected: it duplicates the Recovery hero score and double-counts workout
  energy (FATIGUE + STRENGTH), and demotes the rank-1 spec to match code rather
  than fixing the code.
- **Alt B — FATIGUE = baseline-relative daily reading, NOT accumulated (only
  STRENGTH accumulates).** Rejected: a non-accumulated baseline-relative
  FATIGUE *is* Recovery's HRV-term, which is 50% of the Recovery blend
  (`Recovery.score` = 0.5·HRV + 0.25·RHR + 0.25·sleep), so the two would be
  too tightly correlated to justify both on the detail screen — not literally
  identical, but redundant. An accumulated FATIGUE (a slow HRV trend) is
  distinct from today's Recovery. (This was my initial chat proposal;
  superseded by Decision 4.)
- **Alt C — Keep instantaneous sub-stats; re-define S7 to fire on Recovery-band
  changes or the HEALTH aggregate instead.** Rejected: it abandons the PRODUCT
  §3 promise that *sub-stats* level up, and leaves STRENGTH as a meaningless
  0↔100 daily oscillator on the character sheet.
- **Alt D — Defer all of this; ship S7 against a debug/synthetic trigger.**
  Rejected: S7's dopamine hook would never fire from real data in v0.1, and the
  FATIGUE spec violation would stay shipped.

## ROADMAP impact

- **Stage affected:** Stage 1.
- **Stage scope change:** *added* — one implementation slice (working name
  **S6b — HEALTH sub-stat accumulation model**) lands **before S7**: pure-core
  EWMA primitive + FATIGUE-source fix in `derive` + store-layer accumulation
  wiring + tests. Plus spec edits below.
- **Spec edits this ADR drives** (applied after Codex + owner approval, atomically with status flip to `accepted`):
  - `docs/ROADMAP.md` §2 item 9: FATIGUE source → HRV only (remove "sleep →
    FATIGUE" and "HKWorkout → FATIGUE"; keep HKWorkout → STRENGTH, HRV →
    FATIGUE/Recovery, sleep → Recovery); add a sentence that HEALTH sub-stats
    are accumulated (EWMA, slow decay), not per-snapshot instantaneous; add
    S6b to the scope list before S7 in the load-bearing order.
  - `docs/ROADMAP.zh.md` §2: mirror the above in Chinese.
  - `docs/ROADMAP.md` §4 "Cross-domain wiring clarifications" + `docs/ROADMAP.zh.md`
    §4 (per Codex 1b): the line `HKWorkout → STRENGTH/FATIGUE updates flow via
    HealthSnapshot` drops FATIGUE → becomes `HKWorkout → STRENGTH updates flow
    via HealthSnapshot`. The no-double-count-vs-InferenceLog invariant the
    clarification exists for is preserved verbatim; only the FATIGUE reference
    is removed.
  - `docs/PRODUCT.md` §6 + `docs/PRODUCT.zh.md` §6 cross-domain table, Apple
    Watch workout row (per Codex 1a): `STRENGTH+X · FATIGUE+X (v0.1 via
    HealthSnapshot)` → `STRENGTH+X (v0.1 via HealthSnapshot)`. Workout no
    longer maps directly to FATIGUE; it affects FATIGUE only indirectly via the
    next day's HRV. The `(*)` HKWorkout-routing note below the table is
    unaffected.
  - `docs/PRODUCT.md` §9: FATIGUE row already says HRV (no source change
    needed); add a one-line note that HEALTH sub-stat values accumulate
    (EWMA, slow decay). *(PRODUCT §9 FATIGUE = HRV is the spec we are
    conforming to — it does not change.)*
  - No change to PRODUCT §7 LV formulas (they operate on whatever value is
    stored), Recovery, Strain, or the CORE-root question (that is ADR-003 /
    separate).
- **Plan B (deadline degrade, not cut — revised per Codex 5a):** the EWMA
  primitive applies to **both** STRENGTH and FATIGUE (it is the same one-line
  function — accumulation itself is cheap), so both keep accumulated, stable LV
  crossings and ROADMAP §2's "any HEALTH sub-stat" level-up promise stays
  intact. The FATIGUE daily input stays **baseline-relative** even under Plan B:
  it reuses the already-implemented `recentHRVBaseline` + Recovery HRV-term, so
  it is ~free — it was never the costly part, and an absolute-HRV fallback would
  be *worse* (HRV varies by orders of magnitude, so an un-normalized 0–100 map
  is uncalibrated — per Gemini) **and** more code to write. What is genuinely
  deferrable under deadline pressure is only **half-life tuning** and the
  **back-fill suffix re-derive sophistication** (same-day upsert idempotence
  still ships). Non-cuttable: the FATIGUE-source contradiction fix and EWMA
  accumulation for STRENGTH **and** FATIGUE.
- **Schedule impact (per Codex 5b):** `docs/SCHEDULE.md` has no buffer week and
  names 2026-06-17 as the Stage 1 deadline. S6b is absorbed into the Stage 1
  W2 slice budget (it sits between S6 and S7, both already in W2/W3); it does
  not displace a named milestone. Trigger for the Plan-B degrade above:
  evaluated at the **Day-13 go/no-go review (2026-06-10)** that ROADMAP §2 +
  SCHEDULE already schedule — a *distinct* S6b-readiness check co-located at
  that same review point, not the killer-edge-spike gate itself. If S6b is not
  GREEN + merged by then, fall back to the degraded daily-input + defer tuning
  rather than slip the 2026-06-17 deadline. (Day-14 = 2026-06-11 is the spike
  day, not this trigger.)
- **v1.0-personal date impact:** none. S6b is bounded (pure-core EWMA + store
  wiring + tests + a small `derive` refactor, est. ~1 day); v0.1 target
  2026-06-17 unchanged.

## Implementation

- CONTRACT location (when worker dispatched): worktree at Stage 1 S6b kickoff,
  reviewed per `CLAUDE.md` §1.1 (1b-contract → 1b-tests → worker GREEN → 2b
  diff review → verify-full → PR).
- The CONTRACT pins: the EWMA primitive's signature + purity, the per-stat
  daily-input functions, half-life constants, the store accumulation order
  (strict `capturedAt` ascending) + cold-start, **the mandated upsert +
  suffix-re-derive write path (policy (a))**, **the structural type boundary
  (`healthValue`/`healthLevel` removed from or renamed off the daily-input
  carrier)**, and the RED test list (monotone toward input,
  bounded 0–100, decays on rest, cold-start = input, ordering-dependence,
  duplicate-`capturedAt` / same-day re-write / back-fill, FATIGUE invariant to
  sleep/workout, STRENGTH invariant to non-workout signals).

## Review

- Codex review round 1 (Skill, fresh): **APPROVE WITH CHANGES** (0 BLOCKING /
  5 IMPORTANT / 3 NIT). All applied to this draft: 1a/1b — spec-edit list
  missed workout→FATIGUE sites (PRODUCT §6 EN/ZH Apple Watch row + ROADMAP §4
  EN/ZH cross-domain clarification), now listed; 2a — added write-path
  idempotence/back-fill policy requirement; 2b — added display/level-up
  value-source type boundary; 3a — reworded Alt B ("too correlated", not
  "always agree"); 5a — Plan B revised so FATIGUE keeps EWMA (only daily-input
  refinement + tuning are deferrable), preserving "any sub-stat" S7 level-up;
  5b — added schedule-impact note + Day-13 (2026-06-11) Plan-B trigger; 6a —
  added external-source citation + softened the Whoop/Oura weighting figures.
- Codex review round 2 (Skill, resumed): **APPROVE WITH CHANGES** — all 8
  round-1 fixes confirmed adequate, no new inconsistencies. One IMPORTANT
  remained: the Plan-B trigger was labeled "Day-13 (2026-06-11)" but Day-13 is
  2026-06-10 (2026-06-11 = Day-14). Fixed: trigger pinned to the Day-13
  go/no-go review (2026-06-10), co-located with — distinct from — the
  killer-edge-spike gate. Round 3 on this one-line date fix not warranted.
- Gemini review (auto, on PR #11): 3 MEDIUM, all verified legit + applied.
  (1) type boundary → mandate structural removal/rename of
  `healthValue`/`healthLevel` from the daily-input carrier (reject the
  "document only" escape hatch); (2) write-path → mandate policy (a)
  upsert-and-re-derive, drop the "reject" option (HealthKit back-fills/
  late-syncs are routine); (3) Plan B → do **not** fall back to absolute HRV
  (uncalibrated) — kept baseline-relative (it reuses existing infra, ~free),
  deferring only half-life tuning + back-fill suffix-re-derive. Finding 3
  resolved more thoroughly than Gemini's "static/population baseline"
  suggestion. PR #10's lone Gemini finding (file count 10→11) was already
  fixed by the Codex round-1 pass (stale comment on `bc6f745`).
- Lead approval: <pending>
- Owner approval: <pending>

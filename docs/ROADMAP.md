# NeonSaga — 4-Stage Roadmap (locked, 2026-05-27)

> **Status:** Locked after 7-pass Codex review (see §9 changelog). Living
> document in `docs/ROADMAP.md`.
> **Authority:** ROADMAP defines stage scope and order. PRODUCT.md defines
> product identity. CONTRACT.md (worktree-local) defines exact implementation
> per slice. See `CLAUDE.md` §1.8 for spec hierarchy precedence.

---

## 0. Project premise

NeonSaga is a strict-规范 8-week build for a personally-complete
`v1.0-personal` iOS release. The 4-stage cadence below front-loads HEALTH,
then unlocks the cross-domain killer-edge in Stage 3, then closes
remaining placeholders into a complete 5-tab product at Stage 4.

The strict 规范 in `CLAUDE.md` §1 exists to keep autonomous-agent execution
coherent — friction is intentional. Each stage closes with an iPhone
dev-build install + git tag; if the owner can't use the build on a real
device, the stage is not closed.

---

## 1. Versioning & milestones

| Version | After Stage | Form factor | Value promise | Explicit non-promise |
|---|---|---|---|---|
| v0.1 | Stage 1 | Xcode dev build on owner's iPhone | HEALTH detail rivals Whoop/Oura subjectively; AI Recovery brief explains today's number; Level-up takeover fires on threshold crossings | Cross-domain inference invisible; no WEALTH/GROWTH real surface; Archive unchanged |
| v0.2 | Stage 2 | Xcode dev build on owner's iPhone | Archive surfaces past + future timeline; Quest Design Day flow runnable end-to-end; quest completion ceremony plays | Still no cross-domain validation; INGEST/ORACLE/WEALTH placeholders persist |
| v0.3 | Stage 3 | Xcode dev build on owner's iPhone | Killer-edge visible — one Transaction log → multiple stats fire (including meal-photo → HUNGER multimodal AI); WEALTH detail real; Ingest tab usable | Only 4 inference triggers wired (meal-no-photo / meal-with-photo / gym / flight); reading/location triggers deferred; Oracle/Contracts redesign deferred |
| **v1.0-personal** | Stage 4 | TestFlight build (if Apple Developer ready) else dev build | All 5 tabs real (Oracle ships as same-snapshot multi-turn Q&A with butler-tone narration per ADR-001); Contracts visual parity; dopamine loop wired (quest completion ceremony + level-up takeover + milestone toasts); GROWTH detail | Not yet **public** `v1.0` — cross-domain rules still ≤4; no week-long daily-use validation |
| v1.0 (public) | Post-Stage 4 polish | TestFlight | ≥5 cross-domain rule sets (4 engine triggers from v0.3 + Apple Maps Significant Location auto-TRAVEL+1 added post-Stage 4 as the 5th); owner has used NeonSaga as daily app ≥7 days without falling back to other trackers | — |

**Hard rule:** Each stage exit requires the owner installs that version on their
real iPhone and uses it for the stage's exit-duration:
- Stage 1 (v0.1): ≥1 day
- Stage 2 (v0.2): ≥1 day
- Stage 3 (v0.3): ≥3 days (killer-edge dwell test)
- Stage 4 (v1.0-personal): ≥1 day, must complete a 5-tab happy-path smoke flow (CORE → INGEST log → ORACLE ask → CONTRACTS view → ARCHIVE scrub)
- v1.0 (public): ≥7 days daily use

If the dev build does not run on the iPhone, the stage is not closed and no
git tag is cut.

See `docs/SCHEDULE.md` for week-by-week dates and critical DDLs.

---

## 2. Stage 1 — HEALTH to Whoop/Oura + AI (3-week deadline, target ~2026-06-17)

**Goal:** HEALTH detail page subjectively rivals Whoop/Oura, with an AI Recovery
brief that explains the day's number. Level-up takeover fires for any HEALTH
sub-stat crossing an LV threshold.

**Time framing:** 3 weeks is a **deadline**, not a fixed scope guarantee.
If on Day 18 the install-blocking core is at risk, cut from the bottom of
the Plan B list below — do not slip the deadline.

### Scope (committed, in load-bearing order)

1. **Installable HEALTH detail surface** — Cyberpunk HUD card stack (3–4 cards).
   *Cannot be cut.*
2. **Recovery score** — HRV (rMSSD) baseline-normalized over a rolling 28-day
   window, blended with resting HR and sleep efficiency. Output: 0–100 with a
   3-band classification (RED / YELLOW / GREEN). *Cannot be cut.*
3. **Level-up takeover** — Threshold-crossing detection for any HEALTH sub-stat
   (HUNGER / FATIGUE / STRENGTH); full-screen 0.8s animation + haptic. *Cannot
   be cut* — this is the threshold feedback loop.
4. **Strain score** — HR-zone × time integration; 0–21 Whoop-convention scale.
5. **Sleep architecture** — Deep / REM / Light minutes, time-in-bed vs asleep,
   wake events count, sourced from HealthKit sleep samples.
6. **AI Recovery brief** — Claude call on app open (cached for the day),
   ~300 tokens out, explains "why your Recovery is X today" in 2–3 sentences.
7. **Visual subjective parity** — Final visual polish pass to match Whoop/Oura
   feel (typography, spacing, motion).
8. **Daily streak counter (PRODUCT §3.3 dopamine hook)** — Display in CORE
   first-eye header. Tracks consecutive app-open days via a daily presence
   model, a presence recorder service on scene-active, and a streak source
   service.
9. **HealthSnapshot service (Stage 3 cross-domain prerequisite)** — Bridges
   HealthKit data (HRV, HR, sleep, workouts) → HEALTH sub-stats: HRV →
   FATIGUE / Recovery; HKWorkout → STRENGTH and FATIGUE; sleep samples →
   FATIGUE. **Stage 3's cross-domain engine deliberately routes around
   `HealthSnapshot` (no double-counting via `InferenceLog`)** — see §4
   cross-domain wiring clarifications. Recovery (item 2) and Strain
   (item 4) both consume `HealthSnapshot`; tests in
   `NeonSagaCoreTests/main.swift` verify `HealthSnapshot.derive(...)`
   mapping.

### Plan B cut order (if Day 18 progress is at risk)

Cut from the bottom:
- L4: sound asset polish for level-up takeover (keep placeholder)
- L3: wake events + time-in-bed precision (keep Deep/REM/Light only)
- L2: exact HR-zone strain math (keep simple HR×duration approximation)
- L1: AI brief prose tuning (ship with template phrases, defer LLM tuning)
- **Never cut:** installable HEALTH detail surface, Recovery 0–100, Level-up
  takeover on threshold, **Daily streak counter (PRODUCT §3.3 dopamine
  hook)**, **HealthSnapshot wiring (Stage 3 prerequisite — Recovery and
  Strain already depend on it)**. These five are v0.1's existence reason.

### Killer-edge spike (conditional, off-main, debug-only)

A 1-day spike validating cross-domain inference end-to-end before Stage 3
commits to it as user-visible. Strict guardrails:

- **Day-13 go/no-go gate (2026-06-10)** — At Day 13 of Stage 1, lead reviews
  whether **all 5 "Never cut" items** (Installable HEALTH detail + Recovery
  + Level-up takeover + Daily streak counter + HealthSnapshot wiring) are
  on track to land by **Stage 1 deadline (2026-06-17, Day 20 — SCHEDULE.md
  owns this date)**. If any of the 5 is at risk → skip spike entirely; the
  validation moves to Stage 3 Day 0. If all 5 are on track → run spike on
  Day 14 (2026-06-11).
- **Off-main worktree** — spike code is in a separate worktree, not on the
  feature branch leading to v0.1.
- **Debug-only entry** — no production UI surface touched.
- **1-day hard stop** — by Day 14 EOD (2026-06-11), capture the spike output (whether
  success or failure) in `docs/spikes/stage-1-killer-edge-spike.md`
  (committed, persistent — CONTRACT.md is worktree-local and thus would
  lose the artifact on cleanup), then delete the spike code. Do not extend.
- **Example shape**: gym membership purchase → STRENGTH+5 + monthly-quest
  suggestion (3 lines of rule code + 1 debug button). Single rule, no UI.

### Out of scope (Stage 1)

- WEALTH and GROWTH detail real pages (placeholders remain).
- Production-grade cross-domain inference wiring (Stage 3).
- Archive enhancements (Stage 2).
- Contracts redesign (Stage 4).

### Exit criteria (usage before tag)

- `make test-core` green; `make test` green; **`make verify-full` clean** (numbers reported in commit per `CLAUDE.md` §1.9 verification matrix).
- HEALTH detail screenshot side-by-side Whoop/Oura → owner subjective pass.
- Killer-edge spike output captured in
  `docs/spikes/stage-1-killer-edge-spike.md` if spike ran (or
  "spike-skipped, deferred to Stage 3 Day 0" note if skipped at Day 13 gate).
- **Daily streak counter** visible in CORE header; increments on app open
  across simulated date boundaries (verified via debug time-warp or real
  day rollover during the iPhone-install usage window).
- **HealthSnapshot wiring** tests green; sub-stat values derived from real
  HealthKit samples during owner's iPhone usage window (HRV → FATIGUE,
  HKWorkout → STRENGTH visible).
- Owner installs on iPhone; uses ≥1 day; reports back.
- `v0.1` git tag cut **after** owner confirms usage successful.

### Risks

- HRV baseline math instability in first 28 days. Mitigation: "Calibrating"
  banner if <14 days HRV samples.
- AI brief token budget — cap at one call/day via an `AIBudget` pattern.
- Subjective parity is unmeasurable — accept owner judgment as final.

---

## 3. Stage 2 — ARCHIVE + 事件计划 (1.5-week deadline, target ~2026-06-28)

**Goal:** Archive extends from passive past-timeline to unified past / today /
future view. Quest Design Day flow runs end-to-end. **Quest completion ceremony
ships**.

### Scope (committed)

1. **Archive three-section scroll** — Past / Today / Future, with scrubber and
   filters (date scrub + domain filter chips).
2. **Future-section content** — Active Quest deadlines; Quest Design Day
   (every month-1st); user-confirmed scheduled events.
3. **Quest Design Day flow** — Triggered on month-1st app open. AI suggests
   main + side quests from past-month stat trends → user picks / edits → save.
   Uses a Quest balance enforcer service (suggests, never assigns).
4. **Quest completion ceremony** — When any quest's status flips to `.completed`
   (manual check-off or threshold trigger), a dissolve + XP scroll animation
   fires (per PRODUCT §3.4 dopamine hook).
5. **Archive ↔ Detail tap-through** — Future Quest → Quest editor; Past brief
   → brief detail.

### Out of scope (Stage 2)

- User-defined freeform calendar events (v1.x).
- Contracts visual redesign (Stage 4).
- Cross-domain inference wiring (Stage 3).

### Exit criteria (usage before tag)

- All tests green; **`make verify-full` clean** (per `CLAUDE.md` §1.4 + §1.9).
- Archive scrolls from "30 days ago" to "30 days ahead" smoothly.
- Owner completes Quest Design Day flow on iPhone via debug-menu force-entry.
- Owner sees quest completion ceremony fire end-to-end at least once (manual
  check-off in debug menu suffices).
- Owner uses ≥1 day on iPhone.
- `v0.2` git tag cut **after** owner confirms usage successful.

### Risks

- "Future" section sparse for new users (Quest deadlines + Design Day only).
  Acceptable for personal use; revisit at v1.0.
- Quest Design Day AI suggestions risk drifting toward "coach" tone — keep
  framed as suggestion, not assignment (PRODUCT §5.3 player agency).

---

## 4. Stage 3 — INGEST + 记账 (Cross-domain killer-edge visible) (2-week deadline, target ~2026-07-12)

**Goal:** Ingest tab ships as unified data-input. Transaction model + recording
UI. WEALTH detail real. Cross-domain inference v1 (**4 triggers** including the
meal-photo multimodal AI flow) visibly fires — **this is the killer-edge
validation stage**.

### Scope (committed)

1. **Transaction `@Model`** — `amountCents`, `merchant`, `category`, `date`,
   optional `partySize`, optional `location`. Sign: positive = income.
2. **Ingest tab** — Three primary entries: LOG MEAL, LOG TRANSACTION, LOG ACTIVITY.
3. **LOG TRANSACTION sheet** — Manual: amount / merchant / category /
   party size / date. Auto-fills location from `CLLocationManager`.
4. **LOG MEAL sheet** — Photo + amount + party size; routes through the
   meal vision pipeline.
5. **WEALTH detail view** — Rolling 30-day net, monthly target progress,
   recent transactions (newest first, infinite scroll).
6. **Cross-domain inference v1 (4 triggers wired and user-visible):**
   - **Meal expense (no photo)**: WEALTH−X · COMPANIONSHIP+X (party>1) · TRAVEL+1 (away)
   - **Meal expense + food photo (multimodal AI killer demo)**: WEALTH−X · HUNGER+X (by AI-extracted nutrition) · COMPANIONSHIP+X · TRAVEL+1
   - **Gym membership purchase**: WEALTH−X · prompt "accept STRENGTH monthly quest"
   - **Flight**: WEALTH−X · TRAVEL+map-unlock · COMPANIONSHIP+X (co-travelers)
   - Rules table-driven in `NeonSagaCore`.
7. **InferenceLog visibility** — Each fire produces row in Archive Past section,
   tappable to an inference-explanation sheet.

### Plan B cut order (if Stage 3 timeline at risk)

All 4 cross-domain triggers themselves are non-cuttable (v0.3 promises 4
triggers visibly fire). Plan B **degrades** — not cuts — these items if
timeline at risk:

- L2: Flight trigger's **auto-geocoding of origin/destination** → degrade
  to manual city/country entry (user types instead of `CLLocationManager`
  reverse-geocoding) if location plumbing drags into Stage 3 Day 12.
  **Flight trigger still fires; WEALTH−X · TRAVEL+map-unlock ·
  COMPANIONSHIP+X all still apply; only the city/country auto-extraction is
  replaced by manual entry.** PRODUCT.md §6.2 Flight row notes this Plan B
  fallback explicitly.
- L1: Gym membership trigger's quest-suggestion **modal popup styling** →
  degrade to a passive banner + Archive InferenceLog row "STRENGTH quest
  suggested — see CONTRACTS" if popup UX polish drags past Stage 3 Day 10.
  **Rule still fires; quest still created via Stage 2's Quest model; only
  the modal-interrupt UX degrades** (never cuts the v0.3 4-trigger promise).
- L0: InferenceLog explanation sheet **rich layout** → degrade to a simpler
  sheet that still shows rule name, stat deltas, "why" text, and (for
  meal-photo) the AI-extracted food items list, if rich-sheet visual polish
  drags past Stage 3 Day 11. **Only photo thumbnail rendering / multi-pane
  media styling / fancy transitions may defer to v1.1; the explanation data
  itself stays visible in v0.3** (never cuts the v0.3 "InferenceLog visible
  + tappable" promise).

**Never cut:** All 4 cross-domain triggers wire to InferenceLog (the
firing itself stays — only follow-on UX may degrade), Transaction model,
LOG TRANSACTION sheet, WEALTH detail real, **meal-photo → HUNGER trigger**
(killer multimodal AI demo; v0.3 value promise + exit criteria depend on it).

### Cross-domain wiring clarifications

- **HKWorkout → STRENGTH/FATIGUE updates flow via `HealthSnapshot`, NOT
  `InferenceLog`.** This is a hard invariant (avoids double-counting).
  Stage 1 already wires this. Stage 3 does NOT route HKWorkout through the
  cross-domain rules engine.
- **HKWorkout → active STRENGTH quest progress** is wired in Stage 2's
  quest layer (not Stage 3's cross-domain engine).

### Out of scope (Stage 3)

- AI fallback for unmatched rules (rule path must stabilize first).
- HKWorkout-routed inference (invariant above).
- Reading / OJ / paper log (INTELLECT trigger; v1.x).
- Location significant-change auto-trigger (post-Stage 4 → **v1.0 public
  5th cross-domain rule**); TRAVEL+1 still fires manually from LOG
  TRANSACTION + LOG MEAL location field in v0.3 → v1.0-personal.

### Exit criteria (usage before tag)

- All tests green; **`make verify-full` clean** (per `CLAUDE.md` §1.4 + §1.9).
- Owner logs real meal expense with party=2 on iPhone → WEALTH and
  COMPANIONSHIP both update in real time; Archive shows InferenceLog row.
- Owner takes a real food photo via LOG MEAL → HUNGER updates from AI
  nutrition extraction; Archive shows the multimodal InferenceLog row with
  the AI-extracted food items.
- WEALTH detail shows real data.
- Owner uses ≥3 days on iPhone (killer-edge dwell test).
- Record p50 / p95 tokenized snapshot sizes (HEALTH + WEALTH + GROWTH + active quests + recent Archive InferenceLog) during the ≥3-day dwell test. These measurements anchor the Stage 4 Oracle per-snapshot budget cap (ADR-001). **Fallback if measurement missed** (per Codex round 3 IMPORTANT #2 — proactive gate, not reactive): Stage 4 Oracle CONTRACT cannot be lead-approved until **one** of the following is satisfied: (a) lead runs a token-count dry-run against representative Stage 3 snapshots and sets the cap from that data; OR (b) lead sets a deliberately conservative temporary cap (e.g., 3 turns / 3000 input tokens) bundled with an explicit owner-approved calibration task scheduled for the first 7 days of Stage 4 implementation (with a hard-coded date to revisit). Reactive "wait for owner complaint" is forbidden — cost bounds must exist BEFORE Stage 4 Oracle implementation begins.
- `v0.3` git tag cut **after** owner confirms dwell test successful.

### Risks

- **Load-bearing stage.** If one-log-fires-multi-stat feels gimmicky instead of
  magical, the product loses its hook. Mitigation: insist on the
  InferenceExplanation surface so user can always see why each stat moved.
- Vision API integration (meal-photo) is the highest complexity item.
  Mitigation: validate via Stage 1 Day-14 killer-edge spike if it ran (per
  §2); if vision API is unreliable in production, ship with manual nutrition
  entry as fallback alongside photo input, but the meal-photo trigger itself
  is never cut.

---

## 5. Stage 4 — v1.0-personal (1.5-week deadline, target ~2026-07-22)

**Goal:** Close all 5-tab placeholders. Lock dopamine loop. TestFlight if
possible. Owner sees a **complete personal-use product**.

**Naming:** This is `v1.0-personal`, not `v1.0-alpha` or `v1.0`. "Personal"
acknowledges: the 5 tabs are real, the dopamine loop is wired, the owner can
use it as their daily app. "Not yet public v1.0" because (a) only **4 of the
engine's cross-domain rule sets are wired** (the 5th — Apple Maps Significant
Location auto-TRAVEL+1 — lands post-Stage 4), and (b) the 7-day daily-use
validation has not yet happened.

### Scope, in priority order (cut from bottom if needed)

1. **Release / install stability** — `make verify-full` green on clean checkout;
   iPhone install reproducible; reset/recover path works. *Cannot be cut.*
2. **Contracts visual redesign + quest completion ceremony polish** — Cyberpunk
   HUD parity with CORE. Replaces the semantic-rename quest tab. Pairs with
   Stage 2's quest completion overlay for unified Contracts experience.
3. **Oracle tab — same-snapshot multi-turn Q&A with butler-tone narration (per ADR-001).** *Cannot be cut* — v1.0-personal cannot close with an Oracle placeholder.
   - **Snapshot lock at open**: cross-domain HEALTH + WEALTH + GROWTH + active quests + recent Archive InferenceLog rows.
   - **Re-lock triggers**: Oracle tab closed / app backgrounded >30 min / Oracle foreground-idle >30 min / explicit user refresh.
   - **Re-lock UX**: visible snapshot-timestamp chip; transcript divider + new isolated context on re-lock; previous-snapshot turns NOT sent back to model.
   - **Voice**: third-person factual OR suggestive-conditional. NO first-person, NO second-person imperative, NO named persona, NO cross-snapshot memory.
   - **Per-snapshot budget cap**: anchored to Stage 3 empirical sample snapshots (TBD in Stage 4 CONTRACT, not this ROADMAP).
   - **Answer contract**: user asks via text input; every Oracle answer cites the specific snapshot fields it used (e.g., "Recovery 62 [from HRV 32 ms · RHR 58 · sleep eff 89 %]"). Cited data is non-cuttable — answers without traceable provenance are forbidden.
   - **Archive integration**: "Ask about <day>" prefills Oracle on tap.
4. **Milestone toasts** — Sub-stat reaching 10 / 25 / 50 / 75 / 100 first time
   shows toast (PRODUCT §3.2). Pairs with Stage 1 Level-up takeover.
5. **GROWTH detail view** — INTELLECT / COMPANIONSHIP / TRAVEL three-pane,
   parallel to HEALTH detail shape.
6. **TestFlight build** — Push v1.0-personal to TestFlight if owner has paid
   Apple Developer account; else continue dev-build install.
7. **Demo video** — 90-second walkthrough (post-feature artifact, not feature).

### Stage 4 anti-drift constraints

- **Oracle allows same-snapshot multi-turn Q&A (per ADR-001).** Forbid list: Jarvis persona, cross-snapshot memory, prescriptive lifestyle imperative voice. Stage 4 Oracle CONTRACT must include the prompt-guardrails checklist + lint fail patterns from `docs/templates/CONTRACT.md` §AI prompt guardrails.
- **Contracts redesign preserves player agency** — quests are taken, not
  assigned; AI is balance enforcer, not coach (PRODUCT §5.3).

### Out of scope (Stage 4 → v1.x)

- Reading / paper log inference trigger (v1.1).
- Location auto-TRAVEL+1 (post-Stage 4 → v1.0 public 5th cross-domain rule).
- AI fallback for unmatched rules (v1.1).
- World Map / Inventory / Achievement gallery / Daily comic (v2.0+).
- CloudKit sync (blocked on paid Apple Developer; v1.x).
- Wearables beyond Apple Health (v2.0+).

### Exit criteria (usage before tag)

- All tests green; `make verify-full` clean on clean checkout.
- Plan B: Demo video may be deferred to post-v1.0-personal if Oracle multi-turn implementation absorbs >+3 days. Owner explicit decision required to defer.
- Demo video recorded.
- TestFlight build available if Apple Developer access exists; else dev
  build verified on owner's iPhone.
- **Owner installs and completes 5-tab happy-path smoke flow at least once
  in real-world use:** CORE → INGEST log something → ORACLE ask a question
  → CONTRACTS view active quest → ARCHIVE scrub a past day. ≥1 day usage.
- `v1.0-personal` git tag cut **after** owner confirms 5-tab smoke flow
  successful.
- (For public `v1.0`, post-Stage 4) Owner uses NeonSaga as daily app for
  ≥7 days without falling back to other trackers; cross-domain rules
  reach ≥5.

---

## 6. Strict 规范 (enforced via `CLAUDE.md`)

Non-negotiable for the 8-week run. This section mirrors `CLAUDE.md` §1 —
CLAUDE.md is the operational source of truth; this section is for narrative
review only.

### 6.1 Spec-first CONTRACT gate
See `CLAUDE.md` §1.1. Worker subagents cannot write production code until
CONTRACT has been Codex-reviewed and lead-approved.

### 6.2 TDD red + green discipline (PR-level enforcement, not commit-ancestry hook)
See `CLAUDE.md` §1.2. Pre-commit ancestry hook is softened in favor of
`git log` prefix grep at PR review.

### 6.3 Scope freeze + ADR
See `CLAUDE.md` §1.3. Any feature not in ROADMAP requires ADR.

### 6.4 Per-stage exit ritual
See `CLAUDE.md` §1.4. Uses "tag the stage version" (not "v0.X" specifically).

### 6.5 External code import discipline + source references
See `CLAUDE.md` §1.5. Each CONTRACT introducing external code declares source
references in the CONTRACT — no orphan imports.

### 6.6 Autonomous agent readiness
See `CLAUDE.md` §1.6. Task done-criterion uses verification matrix §1.9, not
blanket `make verify`.

### 6.7 Wiring completeness — no orphaned layers
See `CLAUDE.md` §1.7. Stage exit checklist enforces no dead routes, no
placeholders for shipped surfaces, all schemas + test registrations in place.

### 6.8 Spec hierarchy precedence
See `CLAUDE.md` §1.8 authoritative table. Short version:
**PRODUCT > ROADMAP > SCHEDULE (date authority) > CONTRACT > UI docs**.
ADRs (★ override) supersede any of these by explicit decision + Codex
review. Contradictions require ADR.

### 6.9 Verification matrix
See `CLAUDE.md` §1.9. `test-core` / `test` / `verify-full` matrix replaces
blanket `make verify` for autonomous-agent done-claims.

---

## 7. Anti-goals (explicit reject list)

These are explicitly delayed past v1.0-personal to keep the 8-week run focused:

| Item | Reason | Earliest target |
|---|---|---|
| Cross-domain inference complete (5+ rule sets) | Stage 3 ships 4; rest queued | v1.0 (public, post-Stage 4) |
| Cross-device sync (CloudKit) | Needs paid Apple Developer | After account upgrade |
| World Map / Inventory / Achievement gallery / Daily comic recap | Out of MVP per PRODUCT §11 | v2.0+ |
| Wearables beyond Apple Health (Whoop / Oura / Looki) | Protocol exists, no integration | v2.0+ |
| **Avatar customization depth** (gender / outfit / weapon / race) | PRODUCT §11 | v2.0+ |
| **Level-up sound customization** | PRODUCT §11 | v2.0+ |
| **BOSS as standalone system** | MVP treats boss = enhanced quest | v2.0+ |
| **Multiplayer / leaderboard / PvP** | **BANNED** per PRODUCT §4 IS NOT (single-player game) | Never |
| Social sensing layer (family / friend tagging — non-multiplayer) | Deferred, not banned | v2.0+ |
| User onboarding / tutorial | Single-player, no education per PRODUCT §5.8 | Never |
| Reading / OJ / paper log inference | Stage 4 cut candidate | v1.1 |
| Location auto-TRAVEL+1 | Public-v1.0's 5th cross-domain rule | v1.0 public |
| AI inference fallback (unmatched rules) | Rule path must stabilize first | v1.1 |
| Personified AI persona (named assistant / "Sir, ..." / multi-session memory) | **BANNED** per PRODUCT §4 IS NOT | Never |
| Prescriptive lifestyle imperative voice ("you must X today") | **BANNED** per PRODUCT §4 IS NOT | Never |

---

## 8. Stage-to-PRODUCT.md dopamine-hook coverage

Verification that PRODUCT.md §3's four dopamine hooks all land in v1.0-personal:

| PRODUCT §3 hook | Lands at |
|---|---|
| Level-up takeover (full-screen + haptic + sound) | Stage 1 |
| Milestone toasts (10/25/50/75/100) | Stage 4 |
| Daily streak counter | Stage 1 (scope item 8) |
| Quest completion animation (dissolve + XP scroll) | Stage 2 |

All four ship within the 8-week run.

---

## 9. Codex-review changelog

For traceability; not load-bearing.

### v1 → v2 (10 findings, all applied)

- #1 Stage value/non-value framing → §1 versioning table now has both columns.
- #2 Stage 1 deadline framing → §2 calls 3 weeks a deadline + Plan B cut order.
- #3 Killer-edge spike → §2 dev-only spike (constrained further in v3).
- #4 Stage 1 slip risks → §2 Plan B cut order codified, "never cut" list.
- #5 Stage 4 priority reorder → §5 reordered (re-tightened in v3).
- #6 Source references manifest → CONTRACT template + §6.5.
- #7 Pre-commit hook softened → §6.2 PR-level.
- #8 Quest completion animation → §3 Stage 2 scope + §8 hooks.
- #9 Anti-goals expanded → §7 covers avatar, sound, BOSS, multiplayer ban, Jarvis ban.
- #10 Versioning rename → eventually `v1.0-personal` in v3.

### v2 → v3 (10 findings, all applied)

All applied. Highlights: Stage 4 Oracle moved to #3 with "no chat" guardrail
inlined; spike tightened to Day-13 go/no-go gate + 1-day hard stop;
verification matrix added; spec hierarchy added; wiring completeness
checklist; quest completion ceremony moved to Stage 2; v1.0 reserved for
public release post-Stage 4.

### v3 → v3 + 15-fix (Codex review #3 returned REJECT; 15 fixes applied)

- BLOCKING #1 Day-13 date corrected to 2026-06-10.
- BLOCKING #2 meal-photo → HUNGER moved to "never cut".
- BLOCKING #3 spike output destination changed to `docs/spikes/` (committed).
- IMPORTANT #4-13 and NIT #14-15 all applied.

### v3 + 15-fix → v3 + v4-fix (Codex review #4 returned REJECT; 4 fixes applied)

- **BLOCKING #1** Stage 3 Plan B "degrade-not-cut" — 4 triggers never cut,
  only follow-on UX may degrade. Risk note updated.
- **IMPORTANT #2** `CLAUDE.md` §1.7 sentence clarified (NeonSaga-native files
  do not need classification).
- **IMPORTANT #3** `docs/ROADMAP.md` §6.8 spec hierarchy summary aligned
  with `CLAUDE.md` §1.8 (SCHEDULE rank 2.5 + ADR ★ override).
- **NIT #4** `docs/legacy-disposition.md` "git tag v0.X" → "git tag <stage
  version>". (File subsequently deleted as the strict 规范 simplified —
  wiring completeness in CLAUDE.md §1.7 + source references in CONTRACT
  template now cover the ground that legacy disposition tracked.)

### v5 / v6 / v7 (Codex reviews #5–#7, condensed)

Three further review passes (9 + 4 + 5 findings respectively) refined: (a)
Plan B "degrade-not-cut" pattern enforced across all 3 Stage 3 L-tiers
(L0/L1/L2 are presentation-only — rule + effect always fire); (b) v1.0
public's 5th cross-domain rule made concrete = Apple Maps Significant
Location auto-TRAVEL+1 (post-Stage 4); (c) HealthSnapshot service added as
explicit Stage 1 scope item 9 (Stage 3 cross-domain prerequisite); (d)
Daily streak counter promoted to Never cut + exit criteria; (e) System-
capability axis added to wiring completeness checklist (HealthKit / camera
/ location / CloudKit + Info.plist usage strings + permission flow tested);
(f) `make verify-full` added to all stage exit criteria (was implicit via
§1.4 only); (g) Day-13 spike gate checks all 5 Never-cut items (not just
the original 3); (h) PRODUCT Apple Watch row split = v0.1 stats via
`HealthSnapshot` + v0.2 quest progress via Stage 2 Quest layer; (i)
PRODUCT Flight row notes Plan B manual-entry fallback; (j) Day-21 → Day-20
date arithmetic corrected; (k) `§1.7b` orphan reference → `§1.7`; (l)
SCHEDULE legacy-disposition orphan checklist item replaced with wiring +
source-refs gate; (m) All public docs cleaned to be Praxis-free (project
rebrand).

**Final verdict (v7): APPROVE WITH CHANGES → all 5 v7 findings applied =
locked current state.** This is the regulation set the owner approved
before `git init`.

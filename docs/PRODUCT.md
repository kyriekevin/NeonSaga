# NeonSaga — Product Definition

> 🌐 **Languages**: English (this file) · [中文 docs/PRODUCT.zh.md](PRODUCT.zh.md)

> **Source of truth for product positioning.** Code, plans, and design choices defer to this file.
> Last updated 2026-05-27.

---

## 1. Vision

NeonSaga turns life into an open-world RPG. The reference frame: *Earth Online* (life as MMORPG, taken seriously) + *The Legend of Zelda: Breath of the Wild* (player agency, parallel sub-systems) + *Cyberpunk 2077* (visual frame). The player's real-world actions — meals, workouts, travel, spending, reading — flow into a live RPG character sheet. Stats rise, quests complete, the character levels up. AI is supporting infrastructure; the player is the protagonist.

## 2. Audience & identity goal

**User**: A person who already plays games, wants to level up their real life, and won't respond to guilt-based self-improvement apps. Has an iPhone. Uses English as their operating language.

**Identity transformation**: After six months with NeonSaga, the user becomes a more self-disciplined, growth-oriented version of themselves — not because an app lectured them, but because they played a game where their life was the content. RPG LV is the proxy for self-discipline. AI is the co-pilot, not the coach.

## 3. Compulsion loop

NeonSaga uses existing gaming dopamine wiring, not new self-discipline. The mechanism: RPG mechanics make real-world actions feel rewarding. Habitica uses streak guilt; Apple Health has no hook. NeonSaga's hook is the RPG itself — watching your character's LV / sub-stats / quest progress rise makes you want to go complete the real-world action.

**Four dopamine hooks (all MVP):**

1. **Level-up takeover** — any sub-stat crossing a LV threshold triggers a full-screen takeover (Cyberpunk HUD + 0.8 s animation + haptic + sound). Required for day-30 retention.
2. **Milestone toasts** — sub-stat first reaching 10 / 25 / 50 / 75 / 100 shows an explicit toast (no full Achievement gallery required).
3. **Daily streak counter** — displayed at the top of the character sheet: consecutive days open.
4. **Quest completion animation** — quest card dissolve + XP scroll. Not a checkmark.

## 4. Positioning

### NeonSaga IS
- A multi-sub-stat **RPG character sheet** — a personalized life-stats dashboard with RPG framing
- A **cross-domain inference engine** — one log entry updates multiple stats automatically (killer edge)
- A **monthly user-driven quest system** — main + side quests, AI as balance enforcer
- **Cyberpunk 2077** visual style + **English-first** UI

### NeonSaga IS NOT (positioning inversion, locked 2026-05-22)
- ❌ A data dashboard (not a clone of Apple Health / finance app / Habitica)
- ❌ A personified AI persona (named assistant, "Sir, ...", first-person voice, multi-session memory, profile-building)
- ❌ A prescriptive lifestyle coach (second-person imperative voice — "you must train X / eat Y / sleep at Z"). Player-agency-preserving suggestive-conditional voice is allowed (e.g., "if a STRENGTH quest is active, today is favorable")
- ❌ Social / leaderboard / multiplayer PvP (single-player game)

### Differentiation

| Competitor | What they do | How NeonSaga differs |
|---|---|---|
| **Apple Health** | Passive data display; cross-source aggregation, no narrative | Data → RPG stat → active quest; does not re-build Apple Health visualizations |
| **Habitica** | Manual todo + RPG skin; self-reported completion | Automatic sensing + cross-domain inference replaces manual check-in; Habitica requires self-discipline to log, NeonSaga data arrives automatically |
| **Whoop** | Health-only (recovery/strain); subscription + coach tone | Multi-domain (HEALTH/WEALTH/GROWTH) + player agency (not a coach) |
| **Notion + life templates** | Generic DB; user must build their own system | Out-of-box setup + multimodal AI + iOS native |
| **Cal AI** | Photo → nutrition; single-purpose tool | Photo nutrition is one AI foothold in NeonSaga, not the product; immediately feeds stat chain |
| **Looki L1** | Multimodal wearable hardware + auto vlog | No new hardware needed; vlog/recap deferred to 2.0+ |

## 5. Core principles

1. **Single-app AI integration** — AI client runs inside the iOS app process and sees raw data across all domains. This is the prerequisite for cross-domain inference. It does not conflict with principle 7.
2. **Cross-domain inference is the edge** — one meal expense log → four sub-stats updated. This is what separates NeonSaga from every competitor.
3. **Player agency > AI initiative** — quests are taken by the user (AI enforces balance); AI does not assign tasks.
4. **RPG mechanic, Apple craft** — visual style is full Cyberpunk; engineering is iOS-native SwiftUI + SwiftData to Apple quality standards.
5. **English-first UI** — system language English, Singapore locale, incidental English practice.
6. **Compute full, UI compressed** — AI ingests the full snapshot; UI surface is character sheet + quest log on one screen. See `docs/TOOLCHAIN.md` (when migrated) / `CLAUDE.md` for the NeonSagaCore/NeonSaga split + HealthDataSource/AIProvider protocols.
7. **Local-first with explicit cloud boundary** — SwiftData is the single source of truth, entirely on-device. Cloud sees data only in two cases:
   - **(a) Multimodal images** — food photos sent directly to Claude/OpenAI vision endpoint as single raw images; no caching, no batching, no user-graph construction.
   - **(b) Text inference snapshots** — only the derived feature snapshot needed for the current call (e.g., "past 7 days STRENGTH stat = [...], active quests = [...]"); never the raw transaction list or raw HealthKit samples.
   - **Never**: raw transaction history / raw HK sample stream / user identity / long-term user profile.
8. **No user education** — single-player app; no onboarding copy.

## 6. MVP scope: 3 pillars

### 1. RPG character sheet (multi-sub-stat)

| Stat group | Top-level 0–100 | Sub-stats |
|---|---|---|
| **HEALTH** | avg(HUNGER, FATIGUE, STRENGTH) | HUNGER / FATIGUE / STRENGTH — each 0–100 with its own LV |
| **WEALTH** | See formula in §7 | No sub-stats — single source from `Transaction` aggregator |
| **GROWTH** | avg(INTELLECT, COMPANIONSHIP, TRAVEL) | INTELLECT / COMPANIONSHIP / TRAVEL — extensible skill-tree shape |

### 2. Cross-domain inference engine

One log entry → AI extracts fields + user fills a few → N stats update. Rules table (extensible):

| Trigger | Ships at | User provides | Auto-extracted | Stats touched |
|---|---|---|---|---|
| Meal expense (no photo) | v0.3 | Party size | Location / time / amount / merchant | WEALTH−X · COMPANIONSHIP+X (if party > 1) · TRAVEL+1 (if away from home) |
| Meal expense + food photo | v0.3 | Party size | Same as above + multimodal AI extracts food items / portions / nutrition | WEALTH−X · HUNGER+X (by nutrition) · COMPANIONSHIP+X · TRAVEL+1 |
| Gym membership purchase | v0.3 | — | Merchant / amount | WEALTH−X · suggest "STRENGTH monthly quest" (user must accept) |
| Apple Watch workout (*) | v0.1 (stats) / v0.2 (quest progress) | — | Type / duration / HR / calories | STRENGTH+X · FATIGUE+X (v0.1 via `HealthSnapshot`) · active STRENGTH quest progress (v0.2 via Stage 2 Quest layer) |
| Flight | v0.3 | Co-traveler count | Origin / destination (auto-geocoded; manual entry as Stage 3 Plan B fallback per `ROADMAP.md` §4 L2) / amount | WEALTH−X · TRAVEL+map-unlock · COMPANIONSHIP+X |
| Reading / OJ / paper log | v1.1 | Title / duration | (future AI classification) | INTELLECT+X |
| Apple Maps Significant Location | **v1.0 public** | — | City / country / frequency | TRAVEL+1 (new city) · new map node — iOS CLLocation visit monitoring |

**(\*) HKWorkout routing:** Apple Watch workout flows via `HealthSnapshot` (Stage 1), NOT through this cross-domain inference engine — to avoid double-counting against the engine's `InferenceLog`. Included in this table for completeness as a logical sub-stat → trigger mapping. See `ROADMAP.md` §4 cross-domain wiring clarifications.

**Per-version count:** v0.3 ships **4 engine triggers** (meal-no-photo / meal-with-photo / gym / flight). v1.0 public adds the **5th** (Apple Maps Significant Location auto-TRAVEL+1). v1.1 candidates add reading/OJ/paper log. Apple Watch workout does not count toward the "5+ rules" public-v1.0 promise since it doesn't traverse the engine.

Engine is declarative and table-driven. When no rule matches, the engine returns an empty no-signal result (not nil — `InferenceResult` is non-optional so callers can still record the `ruleVersion` that processed the input). No AI call is made on a no-match. Future AI fallback uses the prompt-schema / budget / cache plumbing already in place and will be injected once the rule set stabilizes. Every rule extension requires a unit test. Rules are versioned.

### 3. Quest system

- **Monthly cadence**: Quest Design Day on the 1st — user + AI design that month's main and side quests together.
- **Main quests**: Long-horizon goals (e.g., "publish a paper this year"), broken into monthly steps.
- **Side quests**: Monthly targets (e.g., "read one book", "run 8 times").
- **AI role**: Balance enforcer — prevents the user from selecting only preferred domains (travel/gaming) and forces sub-stat coverage.
- **Progress tracking**: Automatic (data triggers via the same cross-domain inference) + manual check-off.
- **Reward**: Completion = stat XP gain + unlocks next node in quest chain.

## 7. Computed fields & formulas

| Field | Formula | Notes |
|---|---|---|
| **Per-sub-stat LV** | `LV = floor((current_value / 100) × 99) + 1` → range LV 1–100 | current_value may exceed 100; LV caps at 100 |
| **Per-top-level-stat LV** | `LV = floor(avg of contributing sub-stat LVs)` | WEALTH has no sub-stats → uses WEALTH 0–100 directly → LV |
| **Total LV** | `LV = floor(avg(HEALTH_LV, WEALTH_LV, GROWTH_LV))` | v1 equal-weight |
| **WEALTH 0–100** | `clamp((rolling_30d_net / monthly_target) × 50 + 50, 0, 100)` | `rolling_30d_net = sum(Transaction.amountCents) / 100` — `amountCents` sign: positive = income, negative = expense; divide by 100 to convert cents → CNY before computing ratio. `monthly_target` is a positive integer CNY set in Settings; if nil or zero, WEALTH defaults to fallback = 50. |
| **CLASS** | Top-2 sub-stat-LV pair → lookup table (e.g., STRENGTH+FATIGUE → "Athlete"; INTELLECT+TRAVEL → "Explorer-Scholar"; INTELLECT+COMPANIONSHIP → "Mentor") | Uses SubStat enum raw name; auto-determined, not user-selected; shows toast on change |
| **ALIGNMENT** | v1 static = "Neutral" (vestigial RPG flavor, no function) | Placeholder for a future behavioral inference |
| **DAY** | Days since first stat recorded (not install date) | Surfaces "I've been at this for X days" |
| **CREDITS** | Cumulative `Quest.status == .completed` count × 100 + bonus (TBD) | Decorative RPG currency; consumption mechanics deferred (see Open questions) |
| **EXPERIENCE bar** | `fraction = total_LV_continuous − floor(total_LV_continuous)` where `total_LV_continuous = avg(HEALTH_LV, WEALTH_LV, GROWTH_LV)` without floor | Progress bar displayed next to total LV |

## 8. AI integration roles

| AI role | Trigger | Input | Output |
|---|---|---|---|
| Cross-domain inference | Any log submission | Log entry + user-supplied fields | Stat delta list |
| Multimodal nutrition vision | Food photo taken | Photo | Food items / portions / nutrition breakdown |
| Quest balance enforcer | Quest Design Day | User draft + past 30 days of stats | Adjustment suggestions + balance warnings (NOT prescriptive assignment — see §4 IS NOT no-coach rule) |
| Time-aware brief | Daily AM/PM window | Prior-night recovery + today's active quests, or same-day deltas + completed/idle contracts | Morning Brief or Evening Recap rows |
| Oracle Q&A | User opens Oracle / asks turn | Locked snapshot (cross-domain) + current question | Butler-tone narrated answer (third-person factual or suggestive-conditional voice) with cited snapshot fields. No persona, no cross-snapshot memory, no imperative. See ADR-001 + Stage 4 Oracle CONTRACT. |

## 9. Sub-stat data sources

| Sub-stat | Source | Mode |
|---|---|---|
| HUNGER | Photo → in-app AI nutrition extraction | Semi-manual (user photographs) + AI |
| FATIGUE | HRV from Apple Health (HKHealthDataSource) | Fully automatic |
| STRENGTH | Apple Watch workout type (HKWorkout) | Fully automatic |
| INTELLECT | Reading / OJ / paper log | Manual log (future AI classification) |
| COMPANIONSHIP | Expense reverse-inference + user-supplied party size | Cross-domain inference |
| TRAVEL | iOS CLLocationManager + Significant Location Change + Visit Monitoring | Fully automatic (background); requires `NSLocationAlwaysAndWhenInUseUsageDescription` |
| WEALTH | Transaction model | Manual |

## 10. First-eye view & visual direction

**first-eye view**: The default screen on launch is `Core`: a compressed RPG character sheet that answers "what do I go tackle today -> is my character ready for it?" It is not a comic, not a stats dashboard, and not a chat box.

**Tab IA**: Five tabs — CORE / INGEST / ORACLE / CONTRACTS / ARCHIVE.
- **CORE**: polished first-eye character sheet — LV/EXP header, domain LV meta strip, 0-100 stat bars with trends, Morning Brief, Active Contracts preview, and CONFIG gear.
- **INGEST**: manual and sensed data input surface. Stage 3 ships LOG MEAL / LOG TRANSACTION / LOG ACTIVITY (see `ROADMAP.md` §4).
- **ORACLE**: same-snapshot multi-turn Q&A surface with butler-tone narration. No persona / no cross-snapshot memory / no prescriptive lifestyle voice. Stage 4 ships (see `ROADMAP.md` §5 and ADR-001 for guardrails).
- **CONTRACTS**: quest/mission system, including active and completed contracts plus Quest Design Day. Stage 4 redesigns to Cyberpunk HUD parity.
- **ARCHIVE**: historical journal and event timeline + future-event view. Stage 2 extends from passive past-timeline.

**Visual style (Locked 2026-05-22)**:
- Black background + neon cyan / magenta / yellow accents
- HUD frame + mech panel + translucent holographic layers
- SF Mono primary; Cyberpunk-friendly alternates: Orbitron / Rajdhani
- Subtle glitch artifacts on level-up moment

**Avatar direction**: Illustrated cyberpunk character bust (half-body, not Memoji / not oil painting). Stage 1 ships a bundled illustrated bust asset with procedural fallback. Future tier/class avatar evolution is deferred.

**Language**: English-only UI.

**Current visual reference**: TBD — Stage 1 deliverable.

## 11. Out of scope (MVP 1.0)

Deferred to 2.0+:

- Daily comic recap (AI image-gen vlog)
- World Map (path visualization)
- Inventory (gear / consumables / potion system)
- Achievement gallery (badge / event / milestone system)
- Avatar customization depth (gender / outfit / weapon / race selection)
- Level-up sound customization
- Multi-device wearables (Whoop / Oura / Looki L1; HealthDataSource protocol is implemented but no hardware adapter)
- Social sensing layer (family / friend tagging and interaction)
- BOSS mechanic as a standalone system (MVP: boss = enhanced quest)

See `ROADMAP.md` §7 for the full anti-goal list (includes Stage-4-specific cuts that this PRODUCT.md does not need to enumerate).

---

## Open questions

Parked decisions, not blocking MVP scope lock:

- **Quest chain structure** — linear / branching / main+side dependency graph? To be decided at Quest Design Day implementation.
- **CLASS mapping completeness** — full table of which top-2 sub-stat-LV pairs map to which class name. v1 mapping table is a placeholder; complete table is a follow-on deliverable.
- **Cross-device sync** — CloudKit flip timing. Blocked on paid Apple Developer account readiness (current account is a free Personal Team; custom CloudKit container provisioning is unreliable there).
- **CREDITS consumption** — does the inventory shop actually get built? Depends on the inventory milestone. CREDITS accumulate now; spending mechanics are deferred.

## Source & history

- v1 of NeonSaga PRODUCT.md published 2026-05-27.
- Visual reference: TBD (Stage 1 deliverable).
- UI specs: land under `docs/ui/` as Stage 1+ ship.

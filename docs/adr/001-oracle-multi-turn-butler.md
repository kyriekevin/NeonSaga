# ADR-001 — Oracle multi-turn + butler-tone semantic clarification

> **Type: semantic clarification, NOT feature add.** This ADR does not
> introduce a new tab, data domain, stage, AI persona, AI surface, or v1.0 product promise beyond the existing Stage 4 Oracle tab scope item #3 as modified by this ADR (no additional Oracle modes, sub-tabs, personas, or surfaces).
> It clarifies wording in locked Stage 4 Oracle scope that drifted from owner
> intent during codex review iterations. Required by `CLAUDE.md` §1.3 because
> a locked spec is being modified. Reviewed by Codex (round 1: APPROVE WITH
> CHANGES across 3 rounds, all applied to this v4 draft) before any spec edit.

---

## Status

accepted (v4 final, 2026-05-27)

## Date

2026-05-27

## Context

`PRODUCT.md` §4 IS NOT (locked 2026-05-22, inherited from prior product spec) includes:

> ❌ A **Jarvis**-style personified AI chat interface ("Sir, ..." voice-assistant style)
> ❌ A coach app ("You must complete X today…")

`ROADMAP.md` §5 Stage 4 Oracle scope item #3 (locked via codex review #3, 2026-05-27):

> Snapshot-based: user question (text input) → one snapshot-grounded answer with cited data → end. **No multi-turn conversation, no "Sir, ...", no assistant persona**

`ROADMAP.md` §5 Stage 4 anti-drift constraint:

> Oracle is NOT a chat interface (constraint inlined in scope item #3). If the contract drifts toward chat / multi-turn / personification, reject and re-spec.

In 2026-05-27 session, owner clarified two semantic drifts that were locked without owner round-trip:

1. **"No multi-turn" was codex over-extension.** Owner never said no multi-turn. The clause came from codex review #3 extending the IS NOT "no Jarvis-style personified AI chat" into "no multi-turn conversation". Owner's actual intent was only "no persona / no Sir, ..." — multi-turn Q&A grounded in a single snapshot is desired and matches modern LLM UX expectations.

2. **"Coach" semantic was misread.** Owner's mental model of "coach" = butler-tone narrator surfacing quest progress and stat trends ("STRENGTH quest 进度落后,要不要 INGEST 记一次锻炼"), NOT prescriptive lifestyle coach ("today you must eat X and sleep at Y"). The locked §4 wording "You must complete X today…" correctly excludes lifestyle prescription; the broader "coach app" label inadvertently also excluded butler-tone narration, which is the RPG framing's natural voice.

Adversarial codex review (2026-05-27, post-research-dump pass) confirmed both as STRONG findings:

> Risk of leaving it locked: Oracle may be artificially weak. Risk of reopening too wide: Stage 4 becomes Whoop Coach clone.

**Scope guard (NIT #2 from Codex round 1, tightened per IMPORTANT #3 from round 2):** No new tab is added (Oracle was already in v1.0-personal scope). No new data domain. No new stage. No new AI persona. **No new AI surface beyond the existing Stage 4 Oracle tab scope item #3 as modified by this ADR (no additional Oracle modes, sub-tabs, personas, or surfaces)** — adding a row to PRODUCT §8 AI integration roles documents the existing Oracle role's I/O contract, not a new role. No new product promise vs Whoop / Oura. The Stage 4 deliverable list is unchanged in count and identity; only the wording of Oracle item #3 + the §4 IS NOT framing are clarified.

## Decision

### 1. Same-snapshot multi-turn Q&A allowed in Stage 4 Oracle

When user opens Oracle, a snapshot is locked at that moment (cross-domain HEALTH + WEALTH + GROWTH data + active quests). User may ask multiple turns referencing the same snapshot.

**Snapshot re-lock triggers** (any one):
- Oracle tab closed (user navigates away, app fully exits)
- App backgrounded for >30 min (returns to foreground → re-lock prompt)
- App foregrounded but Oracle tab idle for >30 min (next interaction → re-lock prompt)
- User taps explicit "refresh snapshot" control

**On re-lock**: previous-snapshot transcript turns are visually segmented (divider + "snapshot refreshed 2026-XX-XX HH:MM" chip) AND are **not** sent back into the model context for subsequent turns. Each snapshot has an isolated message window. Visible snapshot timestamp/status chip is required UI element in the Oracle surface.

### 2. Butler-tone narration allowed in Stage 4 Oracle (only)

Oracle's LLM-generated answers may use **butler-tone narration**: suggestive RPG-flavored language referencing the player's stats, quest progress, and stat trends. Examples (DO):

- "Recovery is 62/100 — HRV is 15% below your 28-day baseline; if a STRENGTH quest is active, today is unfavorable for it."
- "Three quests show drift this week. The COMPANIONSHIP quest has the closest deadline."

**Scope limit (IMPORTANT #3 from Codex round 1):** Butler-tone applies to **Stage 4 Oracle output ONLY**. It does NOT extend to CORE Morning/Evening Brief, CONTRACTS quest editor, or any other surface without a separate CONTRACT and ADR. (Locked Stage 1 AI Recovery brief stays terse factual third-person.)

**Naming and identity (IMPORTANT #3 from Codex round 1):** Butler-tone is a **voice style**, not a character. No named butler identity, no avatar, no profile image, no "speaker" attribution. The user is **not** directly addressed as "you" in imperative voice (see Forbid #3). The butler-tone narrator describes player state in third-person ("Recovery is 62") or suggestive-conditional ("if a STRENGTH quest is active, today is favorable").

### 3. Forbid list (unchanged from intent, tightened wording)

- **Personified AI persona** — no "Sir, ..." or any honorific salutation, no named assistant identity ("I'm Oracle, your wellness coach"), no first-person ("I think you should...", "I recommend...", "in my opinion..."), no multi-session memory, no profile-building.
- **Cross-snapshot context** — Oracle has no memory of previous sessions or previous snapshots within the same session. Each snapshot is an isolated context. Re-lock UX (Decision #1) enforces this.
- **Prescriptive lifestyle commands** — no second-person imperative voice ("you must train X today", "you need to eat Y", "you have to sleep by Z", "you should..."). Suggestive-conditional voice is allowed ("if a STRENGTH quest is active, today is favorable for it") — this is the player-agency-preserving voice per PRODUCT §5.3.

### 4. Voice guideline

Oracle answers use one of two modes:

- **Third-person factual**: "Recovery is 62/100 because HRV is 15% below baseline."
- **Suggestive-conditional**: "If a STRENGTH quest is active, today is favorable for it" (no imperative; user decides).

Never: first-person ("I think..."), second-person imperative ("You must..."), persona ("Sir, ..."), cross-session memory ("Last week you...").

## Consequences

### Positive

- Oracle is no longer artificially weak. Same-snapshot multi-turn matches modern LLM UX expectations and lets owner explore HEALTH × WEALTH × GROWTH correlations interactively.
- Butler-tone narration gives NeonSaga's RPG framing a natural voice for Oracle output. This is a structural differentiator from Whoop Coach / Oura Advisor (which cannot reference the user's quest system or cross-domain stats).
- Removes a known semantic drift from the 7-pass locked spec, preventing future agent confusion at Stage 4 CONTRACT writing.

### Negative

- **Budget cap empirical anchoring required (IMPORTANT #5 from Codex round 1).** The per-snapshot cap (turns + tokens) is NOT a fixed ADR number; it is a TBD anchored to Stage 3 empirical sample snapshots. At Stage 3 dwell test (≥3 days iPhone usage), record p50 / p95 tokenized snapshot sizes for HEALTH + WEALTH + GROWTH + active quests + recent Archive InferenceLog rows. Stage 4 Oracle CONTRACT sets the cap as `min(turns ≤ N, total_input_tokens ≤ K × p95_snapshot_size)` where N and K are determined from the measurement. Starting hypothesis for measurement: N=5 turns, K=3 (i.e., 3× snapshot per session), but **not load-bearing on this ADR**.
- **Stage 4 timeline impact revised (IMPORTANT #6 from Codex round 1):** Multi-turn UI requires message list view + persistent input state + budget gauge UI + snapshot lock indicator chip + transcript segmentation on re-lock + prompt-template testing + answer-rendering for two voice modes. Realistic estimate: **+3-4 days** Stage 4 implementation work (not 1-2). Absorbed via: (a) Demo video becomes Plan B cuttable (see ROADMAP edit #4 below); (b) GROWTH detail simplified scope if needed; (c) TestFlight build deferred to dev build if Apple Developer access not ready (already in locked scope as fallback).
- Drift risk toward Whoop Coach clone remains real. Mitigation: explicit Forbid list + concrete prompt-template lint patterns in CONTRACT template (Implementation #5 below).
- Cost per Oracle session increases (more turns = more API tokens). Budget cap (above) bounds this.

### Neutral / open

- Stage 4 Oracle CONTRACT must include a "AI prompt guardrails" subsection citing this ADR's Forbid list + the empirical-anchored budget cap.
- A future ADR may extend butler-tone narration to CORE Morning/Evening Brief if owner finds Stage 4 Oracle butler-tone valuable; deferred until post-v1.0-personal.

## Alternatives considered

- **Alternative A — Maintain status quo (single-shot Q&A, end, no butler).** Rejected because codex confirmed this is review drift, not owner intent. Oracle is artificially weak and the RPG framing has no narrator surface.
- **Alternative B — Full cross-snapshot long-context Jarvis with session memory + named persona.** Rejected because this violates PRODUCT.md §4 IS NOT "no personification" — the core principle survives this ADR. Also risks Whoop Coach clone failure mode (1-person dev cannot out-train Whoop's million-user LLM RAG).
- **Alternative C — Allow multi-turn but ban butler-tone narration** (Oracle stays Q&A-only, no RPG framing). Rejected because butler-tone is the structural differentiator from Whoop Coach (who cannot reference the user's quest system or cross-domain stats). Removing it cedes the structural advantage.
- **Alternative D (IMPORTANT #8 from Codex round 1) — Multi-turn ships in Stage 4; butler-tone narration deferred to v1.x (Stage 4 Oracle uses third-person factual only).** Rejected because owner explicitly clarified in 2026-05-27 session that the in-game butler voice is the differentiator from Whoop Coach / Oura Advisor. Deferring butler-tone makes Stage 4 Oracle indistinguishable from a generic LLM-on-data app; the RPG framing's unique voice is what makes NeonSaga not-Habitica + not-Whoop. Butler-tone implementation cost is small (a prompt-template paragraph + few-shot examples + lint patterns), so deferring it does not buy meaningful timeline relief.

## ROADMAP impact

**Scope guard reiterated:** This ADR introduces **no new tab, data domain, stage, AI persona, AI surface, or v1.0 product promise beyond the existing Stage 4 Oracle tab scope item #3 as modified by this ADR (no additional Oracle modes, sub-tabs, personas, or surfaces)**. Stage 4 deliverable list count is unchanged. Adding a row to PRODUCT §8 AI integration roles **documents the existing Oracle AI role's I/O contract** (Oracle was already a v1.0-personal scoped surface per ROADMAP §5 #3); it does not create a new role. Only the wording of Stage 4 Oracle scope item #3 + the §4 IS NOT framing + the §5 anti-drift constraint are clarified.

- **Stage affected:** Stage 4.
- **Stage scope change:** **none in deliverable identity** — only wording on Oracle scope item #3 + Stage 4 anti-drift constraint is changed. The Oracle tab is already a locked Stage 4 deliverable.
- **Stage 4 timeline impact:** **+3-4 days** of implementation work absorbed via making Demo video Plan-B-cuttable and trimming GROWTH detail scope if needed. v1.0-personal date (2026-07-22) target **unchanged**.
- **v1.0-personal date impact:** **none.** This ADR's clarifications do not shift the deadline.

## Implementation

After this ADR is Codex-approved and Owner-approved, the following spec edits are applied (comprehensive list per Codex round 1 BLOCKING #1):

### EN edits

1. **`docs/PRODUCT.md` §4 IS NOT (lines 39-43)** — split the "Jarvis-style chat interface" + "coach app" rows into clearer, non-overlapping clauses:
   - Replace `❌ A Jarvis-style personified AI chat interface ("Sir, ..." voice-assistant style)` → `❌ A personified AI persona (named assistant, "Sir, ...", first-person voice, multi-session memory, profile-building)`
   - Replace `❌ A coach app ("You must complete X today…")` → `❌ A prescriptive lifestyle coach (second-person imperative voice — "you must train X / eat Y / sleep at Z"). Player-agency-preserving suggestive-conditional voice is allowed (e.g., "if a STRENGTH quest is active, today is favorable")`.
2. **`docs/PRODUCT.md` §10 Tab IA description (line 151)** — replace `ORACLE: single-shot, snapshot-grounded AI Q&A surface — not chat. Stage 4 ships (see ROADMAP §5 and "no chat" guardrail).` → `ORACLE: same-snapshot multi-turn Q&A surface with butler-tone narration. No persona / no cross-snapshot memory / no prescriptive lifestyle voice. Stage 4 ships (see ROADMAP §5 and ADR-001 for guardrails).`
3. **`docs/PRODUCT.md` §8 AI integration roles (line 123 table)** — add new row at the bottom:
   - `| Oracle Q&A | User opens Oracle / asks turn | Locked snapshot (cross-domain) + current question | Butler-tone narrated answer (third-person factual or suggestive-conditional voice) with cited snapshot fields. No persona, no cross-snapshot memory, no imperative. See ADR-001 + Stage 4 Oracle CONTRACT. |`
4. **`docs/ROADMAP.md` §1 v1.0-personal row (line 32)** — replace `(Oracle ships as single-shot Q&A, not chat)` → `(Oracle ships as same-snapshot multi-turn Q&A with butler-tone narration per ADR-001)`.
5. **`docs/ROADMAP.md` §5 Stage 4 scope item #3 (line 323)** — replace the locked text with a structured bulleted item:

```
3. **Oracle tab — same-snapshot multi-turn Q&A with butler-tone narration (per ADR-001).** *Cannot be cut* — v1.0-personal cannot close with an Oracle placeholder.
   - **Snapshot lock at open**: cross-domain HEALTH + WEALTH + GROWTH + active quests + recent Archive InferenceLog rows.
   - **Re-lock triggers**: Oracle tab closed / app backgrounded >30 min / Oracle foreground-idle >30 min / explicit user refresh.
   - **Re-lock UX**: visible snapshot-timestamp chip; transcript divider + new isolated context on re-lock; previous-snapshot turns NOT sent back to model.
   - **Voice**: third-person factual OR suggestive-conditional. NO first-person, NO second-person imperative, NO named persona, NO cross-snapshot memory.
   - **Per-snapshot budget cap**: anchored to Stage 3 empirical sample snapshots (TBD in Stage 4 CONTRACT, not this ROADMAP).
   - **Answer contract**: user asks via text input; every Oracle answer cites the specific snapshot fields it used (e.g., "Recovery 62 [from HRV 32 ms · RHR 58 · sleep eff 89 %]"). Cited data is non-cuttable — answers without traceable provenance are forbidden.
   - **Archive integration**: "Ask about <day>" prefills Oracle on tap.
```
6. **`docs/ROADMAP.md` §5 Stage 4 anti-drift constraints (line 342)** — replace `Oracle is NOT a chat interface (constraint inlined in scope item #3). If the contract drifts toward chat / multi-turn / personification, reject and re-spec. The contract template includes a "no chat" assertion field.` → `Oracle allows same-snapshot multi-turn Q&A (per ADR-001). Forbid list: Jarvis persona, cross-snapshot memory, prescriptive lifestyle imperative voice. Stage 4 Oracle CONTRACT must include the prompt-guardrails checklist from \`docs/templates/CONTRACT.md\` and the lint fail patterns (see Implementation #9 below).`
7. **`docs/ROADMAP.md` §5 Stage 4 exit criteria (line 358)** — make Demo video Plan-B-cuttable. Add this bullet before the Demo video line: `- Plan B: Demo video may be deferred to post-v1.0-personal if Oracle multi-turn implementation absorbs >+3 days. Owner explicit decision required to defer.`
8. **`docs/ROADMAP.md` §7 anti-goals (line 435 row)** — replace `| Jarvis-style chat AI / personified AI | BANNED per PRODUCT §4 IS NOT | Never |` → `| Personified AI persona (named assistant / "Sir, ..." / multi-session memory) | BANNED per PRODUCT §4 IS NOT | Never |` and add adjacent row: `| Prescriptive lifestyle imperative voice ("you must X today") | BANNED per PRODUCT §4 IS NOT | Never |`.
9. **`docs/templates/CONTRACT.md`** — add new section "AI prompt guardrails (§4 IS NOT enforcement)" after the existing Wiring completeness checklist (~line 122). Section contents:

```markdown
## AI prompt guardrails (per PRODUCT.md §4 IS NOT + ADR-001)

Required if this CONTRACT introduces or modifies any AI prompt template
(Morning Brief, Evening Recap, Oracle answer, Quest balance enforcer brief,
meal-photo vision prompt, any other LLM-bound output that reaches the user).

Lint the prompt template AND a representative sample of generated outputs
against these fail patterns. **All regex must be applied case-insensitively
(`/i` flag).** The pattern set below is **non-exhaustive starting point** —
extend when new bypass forms are discovered. Mark each as it passes:

- [ ] No honorific salutations: regex `\b(sir|master|my\s+lord|m'?lord|ma'?am|boss|chief)\b` (case-insensitive) matches zero times in AI output
- [ ] No first-person AI: regex `\b(i\s+(think|recommend|suggest|am|will|believe|feel|can|would|hope|advise|notice[d]?|find|found|observe[d]?|see|conclude|note)|i['’](ll|d|m|ve|re)|my\s+(advice|recommendation|view|opinion|sense|read))\b` (case-insensitive) matches zero times in AI output (both straight `'` and curly `’` apostrophes)
- [ ] No second-person imperative: regex `\b(you\s+(must|need\s+to|have\s+to|should|ought\s+to|gotta)|don'?t\s+forget\s+to|please\s+(make\s+sure|remember\s+to|do|don'?t))\b` (case-insensitive) matches zero times
- [ ] No collective imperative bypass: regex `\b(we\s+(should|need\s+to|must|ought\s+to|have\s+to|gotta)|let'?s\b)` (case-insensitive) matches zero times
- [ ] No pseudo-third-person persona bypass: regex `\b(as\s+your|the\s+(system|app|helper|assistant|oracle)\s+(recommends|thinks|suggests|believes|advises|notes|sees)|i['’]m\s+here\s+to|as\s+an?\s+ai|your\s+assistant)\b` (case-insensitive) matches zero times — these evade first-person regex but functionally assert AI persona
- [ ] No cross-snapshot memory references: regex `\b(previous\s+(session|snapshot|conversation|chat)|last\s+time|earlier\s+(you|we|today)|remember\s+(when|that|how)|your\s+(history|profile|past|usual))\b` (case-insensitive) matches zero times
- [ ] No named assistant identity: prompt template does not assign the AI a name, avatar, speaker persona, or any consistent "voice character"
- [ ] Voice is third-person factual ("Recovery is 62/100 because…") or suggestive-conditional ("if X quest is active, today is favorable for it") only — no imperative, no first-person, no honorific
- [ ] Snapshot-bounded: prompt context does not include data from before the current snapshot lock (Oracle) or current day's window (briefs)

**Negative voice examples** (any of these in generated output = lint fail, even if they slip a specific regex):

- "we should try…" / "let's review…" (collective imperative)
- "please make sure to drink water" (politely-imperative)
- "your assistant suggests…" / "as your AI…" / "Oracle recommends…" (persona substitute)
- "I noticed your sleep was off" (curly-apostrophe + first-person verb)
- "remember when you…" / "your usual pattern is…" (cross-snapshot)

If any check fails, the CONTRACT cannot be lead-approved. The regex set is a **non-exhaustive starting point** — when discovering new bypass patterns in practice, extend the regex set + negative examples here and reference the amending ADR.
```

### Stage 3 wiring (IMPORTANT #2 from Codex round 2)

10. **`docs/ROADMAP.md` §4 Stage 3 exit criteria** — add new bullet: `- Record p50 / p95 tokenized snapshot sizes (HEALTH + WEALTH + GROWTH + active quests + recent Archive InferenceLog) during the ≥3-day dwell test. These measurements anchor the Stage 4 Oracle per-snapshot budget cap (ADR-001).` This ensures Stage 4 Oracle CONTRACT has the empirical data needed to set its cap. **Fallback if measurement missed** (per Codex round 3 IMPORTANT #2 — proactive gate, not reactive): Stage 4 Oracle CONTRACT cannot be lead-approved until **one** of the following is satisfied: (a) lead runs a token-count dry-run against representative Stage 3 snapshots and sets the cap from that data; OR (b) lead sets a deliberately conservative temporary cap (e.g., 3 turns / 3000 input tokens) bundled with an explicit owner-approved calibration task scheduled for the first 7 days of Stage 4 implementation (with a hard-coded date to revisit). Reactive "wait for owner complaint" is forbidden — cost bounds must exist BEFORE Stage 4 Oracle implementation begins.

### ZH mirror edits (full set, BLOCKING #1 from Codex round 2)

11. **`docs/PRODUCT.zh.md` §4 IS NOT (line 41 area)** — mirror EN edit #1 in Chinese: split Jarvis row + clarify coach row.
12. **`docs/PRODUCT.zh.md` §10 Tab IA description (line 151)** — mirror EN edit #2 in Chinese.
13. **`docs/PRODUCT.zh.md` §8 AI integration roles (line 123 area)** — mirror EN edit #3: add Oracle Q&A row in Chinese.
14. **`docs/ROADMAP.zh.md` §1 v1.0-personal row (line 36)** — mirror EN edit #4 in Chinese.
15. **`docs/ROADMAP.zh.md` §5 Stage 4 scope #3 (line 301)** — mirror EN edit #5 (bulleted form, **including the Answer contract bullet with cited-snapshot-fields requirement**) in Chinese.
16. **`docs/ROADMAP.zh.md` §5 Stage 4 anti-drift constraints (line 317)** — mirror EN edit #6 in Chinese.
17. **`docs/ROADMAP.zh.md` §5 Stage 4 exit criteria Demo Plan B (line 313 area)** — mirror EN edit #7 in Chinese.
18. **`docs/ROADMAP.zh.md` §7 anti-goals (line 407)** — mirror EN edit #8 in Chinese.
19. **`docs/ROADMAP.zh.md` §4 Stage 3 exit criteria** — mirror EN edit #10 in Chinese.

### Post-acceptance edits (NIT #9 from Codex round 1)

20. **`docs/STATUS.md` line 40 (file counts table)** — update `docs/adr/ | 0 ADRs (template only)` → `docs/adr/ | 1 ADR + template (ADR-001 accepted)`.

### CONTRACT location (when worker dispatched)

Stage 4 Oracle slice CONTRACT will be written in worktree at Stage 4 kickoff and reviewed per `CLAUDE.md` §1.1.

## Review

- Codex review round 1: APPROVE WITH CHANGES (9 findings: 1 BLOCKING / 6 IMPORTANT / 2 NIT). All 9 applied to v2.
- Codex review round 2: APPROVE WITH CHANGES (5 findings: 1 BLOCKING / 2 IMPORTANT / 2 NIT). BLOCKING was ZH mirror set incomplete (covered only 4 of 8 ZH sites); IMPORTANT #2 added Stage 3 measurement wiring (Implementation #10); IMPORTANT #3 tightened scope-guard wording for "no new AI role" vs PRODUCT §8 row; NIT #4 bulletized Stage 4 scope #3 (Implementation #5); NIT #5 added case-insensitive flag + persona-substitute bypass patterns to prompt-lint (Implementation #9). All 5 applied to v3.
- Codex review round 3 (via Skill, higher-quality system prompt): APPROVE WITH CHANGES, 0 BLOCKING (5 findings: 3 IMPORTANT / 2 NIT). IMPORTANT #1 — bulleted Stage 4 scope #3 had dropped "with cited data" constraint from locked text → added Answer contract bullet (Implementation #5). IMPORTANT #2 — Stage 3 measurement fallback was reactive ("wait for owner complaint") → rewritten as proactive gate (Implementation #10): CONTRACT cannot approve without dry-run measurement OR conservative cap + scheduled calibration task. IMPORTANT #3 — prompt-lint regex still had bypasses ("we should", "let's", "please make sure", curly apostrophes, "I advise", "your assistant", "as an AI", "Oracle recommends") → expanded patterns + added negative-examples section (Implementation #9). NIT #4 — "beyond already-scoped Oracle" was loose → tightened to "beyond existing Stage 4 Oracle tab scope item #3 as modified by this ADR; no additional Oracle modes, sub-tabs, personas, or surfaces" in 3 places. NIT #5 — metadata still said "v2 draft" / "v2 after round 1" → updated to v4 / rounds 1–3. All 5 applied to this v4 draft.
- Codex review round 4 (Skill, on ADR v4 text): APPROVE, 0 findings. ADR text locked at v4.
- Codex review round 5 (Skill, on applied spec-edit diffs across 6 files): APPROVE WITH CHANGES (0 BLOCKING / 2 IMPORTANT / 1 NIT). Findings applied in fix-pass: (a) prompt-lint regex extended to cover curly apostrophes in `m'?lord` / `ma'?am` / `don'?t` / `let'?s` via `['’]?` apostrophe class, and to match bare "Oracle recommends" without "the" prefix via `(?:the\s+)?`; (b) "Implementation #9 below" cross-reference in ROADMAP.md §5 anti-drift (and ZH mirror) replaced with explicit "`docs/templates/CONTRACT.md` §AI prompt guardrails"; (c) STATUS.md edit #20 reverted from "1 ADR + template (ADR-001 accepted)" to "1 ADR in review + template (ADR-001 v4, pending owner final lock)" to resolve premature "accepted" claim — to be re-applied atomically with ADR status flip at lock time. Round 6 on fix diffs deferred unless owner requests.
- Lead approval: 2026-05-27 (owner read fix diffs and approved with "我觉得可以没问题,你可以接着往下推了")
- Owner approval: 2026-05-27
- Date proposed → accepted: 2026-05-27 — STATUS.md edit #20 re-applied atomically with this lock

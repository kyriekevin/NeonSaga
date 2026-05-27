# CONTRACT — <Stage / Feature Name>

> **Worktree-local process artifact.** This file is NOT committed to the PR.
> It documents the brief sent to the reviewer (Codex on Claude Code flow,
> Gemini on Codex flow) for first-pass review before any production code is
> written. After approval, the worker implements against it; after the diff
> lands, the reviewer reviews the diff against this file.
>
> Required by `CLAUDE.md` §1.1. Copy this file into the worktree as
> `CONTRACT.md`, fill in every section, then dispatch first-pass review.

---

## Meta

- Stage: <e.g., Stage 1 / Stage 2 / ADR-007-driven>
- Date: YYYY-MM-DD
- Author (lead): <agent name + model>
- Reviewer: <Codex / Gemini>
- Worker (subagent): <Sonnet / GPT-5.x / TBD>
- Source ROADMAP section: <e.g., ROADMAP §2 Stage 1>

## Goal

<One sentence — user-visible outcome. No architecture in this line.>

## Scope (committed)

<Bulleted. User-visible behavior + UI surfaces only. Architecture goes
below in "Architecture / interfaces touched".>

- ...
- ...

## Out of scope (this CONTRACT)

<Bulleted. What could be confused as in-scope but isn't, with one-line
reason. This prevents scope creep mid-implementation.>

- ...
- ...

## Architecture / interfaces touched

<Bulleted. Files that will change, protocols modified or added, public API
surface changes. List by repo-relative path.>

- `NeonSagaCore/Sources/NeonSagaCore/<File>.swift` — <what changes>
- `NeonSaga/Services/<File>.swift` — <what changes>
- ...

## Required behavior

<Numbered list. What the user can do after this lands. Each item must be
observable from the UI / device or from a test.>

1. ...
2. ...

## Failing tests defining "done" (TDD red phase)

<Test names + brief assertions. These are the tests committed in the `red:`
commit before any implementation.>

- `NeonSagaCoreTests/main.swift` — `group("<name>")` `expect(...)` <what>
- `NeonSagaTests/<File>.swift` — `func test<Name>()` <what>

## Source references (§1.5)

<If this CONTRACT introduces files from any external source (prior-art
codebases, sample code, SDK examples, dependencies), list them here.
If no external imports, write "No external imports in this CONTRACT.">

### Files imported

| Source identifier | New path in NeonSaga | Reason |
|---|---|---|
| <path/URL/library> | `NeonSagaCore/.../X.swift` | <why import vs. write fresh> |
| ... | ... | ... |

### Module rename points

<List of imports, `Package.swift` edits, `project.yml` edits, custom runner
registration entries that need updating.>

- ...

### SwiftData @Model schema additions

<List of new @Model classes added to `NeonSagaApp.swift` ModelContainer.>

- ...

### Asset additions

<List of asset names + sources (e.g., Codex-generated PNG, SF Symbol, etc.).>

- ...

### License / attribution

<If imported code carries a license, note here.>

- ...

## Open questions

<Bulleted. Questions the lead/reviewer must resolve before code starts.>

- ...

## Plan B cut order

<Numbered. Bottom-of-list items can be cut if stage timeline is at risk.
Top items are "cannot cut" — the CONTRACT's existence reason.>

1. Cannot cut: <core deliverable>
2. Cannot cut: <core deliverable>
3. Can cut: <polish item>
4. First to cut: <leaf detail>

## Verification

<How the lead verifies done, before git tag. Pick the appropriate matrix row
from `CLAUDE.md` §1.9.>

- Verification command: <`make test-core` | `make test` | `make verify-full`>
- Screenshot diff: `docs/screenshots/<name>.png` (before/after if applicable)
- iPhone install: yes / no
- Owner dwell required: <duration>

## Wiring completeness (§1.7)

Required at stage close. Mark each as it lands:

- [ ] All shipped tabs reachable from `RootTab.allCases` / `RootView`
- [ ] `project.yml` updated for new files; `make gen` produces clean diff
- [ ] All new `@Model` classes added to `NeonSagaApp.swift` ModelContainer schema
- [ ] All new core tests registered in `NeonSagaCoreTests/main.swift`
- [ ] All new iOS XCTest files included in `NeonSagaTests/` target via `project.yml`
- [ ] Screenshots updated in `docs/screenshots/` for any visual change
- [ ] System capabilities (HealthKit / camera / photo library / location / CloudKit / network) that this CONTRACT touches: declared in `project.yml` entitlements + matching `Info.plist` usage strings; permission flow tested in simulator and on device
- [ ] `docs/STATUS.md` reflects new shipped state
- [ ] No placeholder views for surfaces this CONTRACT shipped real
- [ ] No dead routes / unreachable code
- [ ] All external imports declared in "Source references" section above

## AI prompt guardrails (per PRODUCT.md §4 IS NOT + ADR-001)

Required if this CONTRACT introduces or modifies any AI prompt template
(Morning Brief, Evening Recap, Oracle answer, Quest balance enforcer brief,
meal-photo vision prompt, any other LLM-bound output that reaches the user).

Lint the prompt template AND a representative sample of generated outputs
against these fail patterns. **All regex must be applied case-insensitively
(`/i` flag).** The pattern set below is **non-exhaustive starting point** —
extend when new bypass forms are discovered. Mark each as it passes:

- [ ] No honorific salutations: regex `\b(sir|master|my\s+lord|m['’]?lord|ma['’]?am|boss|chief)\b` (case-insensitive) matches zero times in AI output (covers both straight `'` and curly `’` apostrophes)
- [ ] No first-person AI: regex `\b(i\s+(think|recommend|suggest|am|will|believe|feel|can|would|hope|advise|notice[d]?|find|found|observe[d]?|see|conclude|note)|i['’](ll|d|m|ve|re)|my\s+(advice|recommendation|view|opinion|sense|read))\b` (case-insensitive) matches zero times in AI output (both straight `'` and curly `’` apostrophes)
- [ ] No second-person imperative: regex `\b(you\s+(must|need\s+to|have\s+to|should|ought\s+to|gotta)|don['’]?t\s+forget\s+to|please\s+(make\s+sure|remember\s+to|do|don['’]?t))\b` (case-insensitive) matches zero times (covers both straight `'` and curly `’` apostrophes)
- [ ] No collective imperative bypass: regex `\b(we\s+(should|need\s+to|must|ought\s+to|have\s+to|gotta)|let['’]?s\b)` (case-insensitive) matches zero times (covers both straight `'` and curly `’` apostrophes)
- [ ] No pseudo-third-person persona bypass: regex `\b(as\s+your|(?:the\s+)?(system|app|helper|assistant|oracle)\s+(recommends|thinks|suggests|believes|advises|notes|sees)|i['’]m\s+here\s+to|as\s+an?\s+ai|your\s+assistant)\b` (case-insensitive) matches zero times — these evade first-person regex but functionally assert AI persona ("the" prefix is optional so bare "Oracle recommends" also matches)
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

## Review trail

<Filled in as review happens. The CONTRACT lives in the worktree, so this
section can be edited during the process.>

- Contract review (first pass): <Codex result summary or `task ID`>
- Implementation review (second pass): <Codex result summary>
- Lead approval (for merge): <date>
- Owner approval (for stage exit): <date, if Stage-bounded CONTRACT>

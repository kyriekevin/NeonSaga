# ADR-003 — UI-eval tooling: a layered SwiftUI verification ladder

> Architectural Decision Record. Required by `CLAUDE.md` §1.3 because it amends the
> §1.9 verification matrix (adds UI-lifecycle and simulator-smoke verification not in
> the locked process) and introduces UI test tooling not named in `docs/ROADMAP.md`.
> Reviewed by Codex before any code change.

---

## Status

accepted (2026-05-30)

## Date

2026-05-30

## Context

Our correctness signal is strong on **pure logic** and on **view-model state**, and
blind on **everything between a passing view-model test and a screen that actually
works**. Two test layers exist today:

- `NeonSagaCore` custom-runner tests (CLAUDE.md §4) — pure Swift, sub-second (~150 tests).
- `NeonSagaTests/` iOS XCTest — `@Model` and view-model tests. The latter
  (`HealthDetailViewModelTests`) deliberately asserts the VM's **published state**
  (the `RecoveryBand` enum, numeric `*Fraction` values, placeholder strings), not
  `Color` or geometry — semantic, not pixel.

Per `CLAUDE.md` §1.9, a SwiftUI change is verified by `make test` (iOS XCTest). But
the iOS tests we write assert the **view model**, never the **view's ownership and
lifecycle of that view model**. The bug class this misses is one we have actually
hit and caught **by hand, not by a test**:

- The `HealthDetailContainerView` doc comment in `NeonSaga/Views/HealthDetailView.swift`
  records that `State(initialValue: VM(...))` re-runs the VM's synchronous store
  fetch on **every parent body pass**, and works around it with an optional `@State`
  + `.onAppear` single-construction. **No test in the suite would catch a regression
  of that fix** — a VM unit test passes identically whether the view constructs the
  VM once or on every render.
- §1.7 (wiring completeness) already mandates the relevant reachability checks, but
  they are **review-time only** — nothing executes them to confirm the app launches,
  the shipped routes resolve, and each surface renders without crashing. §1.4's
  Stage-4 exit ritual already **mandates a 5-tab happy-path smoke
  flow** (CLAUDE.md §1.4 defines the exact step sequence) — with **no tooling
  specified to run it**.

The owner flagged (2026-05-29 infra-sprint scoping) that **past UI implementation had
outsized problems** while logic stayed clean — consistent with the gap above: the
rendering/lifecycle layer has no eval. This pays off right before the UI-heavy
slices: **S10** (CORE first-eye root — PRODUCT §10 + ROADMAP §2 item 8, the first
multi-surface navigation), then the **Stage-4** 5-tab IA.

This is **not** a request for pixel-perfect snapshot testing. Owner direction is
explicit: target **view-model ownership, `@State`/`@StateObject` lifecycle, and
re-render state retention — not pixels.** Pixel/snapshot diffing re-baselines on
every intentional visual tweak and would tax a solo, fast-moving Stage-1/2 cadence
for little signal.

## Decision

Adopt a **layered UI-eval ladder**: cheapest layer first, climb only when a real
regression escapes the layer below. This ADR decides the **ladder, each layer's
trigger, and the §1.9 amendment**; exact target wiring and any dependency pin are
CONTRACT-level detail for the slice that first needs each layer (as ADR-002 deferred
its constants to the implementing CONTRACT).

### Layer 0 — Lifecycle review checklist (zero new deps; seed this sprint)

A review-time checklist applied to every PR that adds or changes a SwiftUI view,
targeting the ownership/lifecycle bug class that unit tests are structurally blind
to. It **references** §1.7/§1.4 rather than restating them, and adds only the
lifecycle items those sections do not carry:

- [ ] A view model that does I/O or observation is **constructed once** — optional
  `@State` + `.onAppear` when `init` does I/O (the `HealthDetailContainerView`
  pattern), or a plain `@State` of the `@Observable` VM owned at the right level (the
  SwiftUI-Observation idiom; `@StateObject` is the `ObservableObject` equivalent).
  **Never** `State(initialValue: VM(...))` when `init` does work — it re-runs every
  body pass.
- [ ] View-model state **survives parent re-render** (owned by `@State`/`@StateObject`
  at the right level, not re-created inside `body`).
- [ ] An `@Environment` value used to **construct** a store or view model (e.g.
  `modelContext` → `HealthSnapshotStore`) is read once at the entry view and the
  constructed object is passed down — not re-derived to rebuild it deep in the tree.
  (Ordinary descendant `@Environment` reads for styling/context are fine.)
- [ ] No store I/O or business logic in `body` (or a computed `body` path); `body`
  reads already-computed VM state.
- [ ] An `@Observable` VM exposes displayed values as stored/computed properties so
  the view tracks only what it reads.
- [ ] Reachability + screenshots are confirmed per **§1.7 / §1.4** (referenced here,
  not duplicated).

Layer 0 is the cheapest layer and catches the bug we have actually seen. Until the
`slice-pipeline` skill (CLAUDE.md §9) mirrors it (a follow-on Layer-0 implementation
step — see Implementation, **not in this PR**), **this ADR is the checklist's
authoritative home**; the skill sub-checklist will then **cite** this ADR and the
§-numbers above rather than restate them (cite the spec, don't fork it).

### Layer 1 — Simulator smoke (XCUITest + `ios-simulator-skill`)

A minimal **launch-and-navigate** UI test plus screenshot capture, run in the
simulator. It proves what unit tests cannot: the app launches, the entry view
constructs its VM without crashing, tabs are reachable (the §1.7 wiring check made
**executable**), and each surface renders. Layer 1 is the natural runner for the
**§1.4 Stage-4 5-tab happy-path smoke flow**, which is already mandated but has no
tooling. It uses the already-registered `ios-simulator-skill` (CLAUDE.md §9) for
automation and `docs/screenshots/` capture (§1.4 / §1.7).

**Trigger to build it:** the first slice that ships **navigation between ≥2 real
surfaces** — i.e. S10 (CORE root) / the Stage-4 tab IA. **Not** built for the current
single-screen `HealthDetailView`.

### Layer 2 — Structural assertions (ViewInspector), on demand only

A **test-only** SwiftPM dependency (`ViewInspector`) for asserting a view's
**structure-from-state** mapping (e.g. "Recovery `.calibrating` renders the
calibrating label; `.scored` renders value + band") — semantic structure, still **not**
pixels. Adding it introduces a third-party test dependency, so it is gated on the
forthcoming **agent supply-chain hardening ADR** (sprint item #5): pin to a SHA,
test-target only, inventoried.

**Trigger to add it:** a specific view whose state→structure conditional logic is
complex enough that Layer 0 review + Layer 1 smoke have **let a real regression
through**. Not adopted pre-emptively — an unused dependency is net-negative.

### Explicitly NOT decided / NOT adopted

- **Pixel / snapshot diffing** (`swift-snapshot-testing`) as a default gate —
  rejected (brittle; owner direction "not pixels"); see Alternatives. May be revisited
  **per-surface for the Stage-4 visual-parity slice (S11) only.**
- The exact XCUITest target/scheme layout and the `ViewInspector` pin — CONTRACT-level
  for the slice that first needs Layer 1 / Layer 2.

## Consequences

### Positive

- Closes the unit-test-to-working-screen gap with the **cheapest layer that catches
  our actual bug class** (VM single-construction), at zero dependency cost.
- Makes two already-mandated-but-unautomated checks executable: §1.7 tab reachability
  and the §1.4 Stage-4 5-tab smoke flow.
- Avoids brittle pixel gates; preserves the fast solo cadence.
- Defers all dependency/tooling cost to the slice that proves each layer is needed
  (don't one-shot infra — build each layer only when it earns its place).

### Negative

- Layer 0 is review discipline, not an automated gate — an inattentive reviewer can
  skip it (mitigated by baking it into the `slice-pipeline` skill so it rides every
  slice).
- Layer 1 adds simulator-dependent tests (slower than `test-core`; need a booted sim)
  — scoped to navigation slices, and `make test` already boots the simulator.
- Layer 2, if adopted, adds a third-party test dependency plus its maintenance and
  supply-chain surface (the sprint item #5 gate is the mitigation).

### Neutral / open

- The §1.9 amendment **adds** UI-eval rows but changes no existing row's command;
  `make test` / `make verify-full` still run the iOS bundle.
- Whether Layer 1 lives in `NeonSagaTests/` (XCTest UI) or a separate
  `NeonSagaUITests/` target is a CONTRACT-level choice when S10 builds it.
- `ViewInspector` tracks Swift/SwiftUI versions; a toolchain bump could force a pin
  update or a drop. Acceptable because Layer 2 is opt-in per surface.

## Alternatives considered

- **Snapshot/pixel testing as the default UI gate** (`swift-snapshot-testing`).
  Rejected: re-baselines on every intentional visual change, high false-positive rate,
  and the owner's direction is explicitly "ownership/lifecycle, not pixels". Held in
  reserve for S11 visual-parity only.
- **ViewInspector for every view from the start.** Rejected: pays a third-party
  dependency + supply-chain surface before any regression proves it is needed; Layer 0
  review catches the bug class we have actually seen, for free.
- **Rely on the existing VM unit tests alone.** Rejected: they are structurally blind
  to view↔VM ownership/lifecycle — they pass identically whether the view constructs
  the VM once or on every render (the exact bug `HealthDetailContainerView` works
  around by hand).
- **A single big "UI testing" adoption now.** Rejected: one-shotting infra is wasteful;
  the ladder lets each layer earn its place from lived slice experience.

## ROADMAP impact

- **Stage affected:** cross-cutting (verification infra). Value lands at **S10** (CORE
  root — first multi-surface navigation) and **Stage 4** (5-tab IA smoke).
- **Stage scope change:** **none to product scope.** This amends the **process spec**
  (§1.9 verification matrix), not ROADMAP feature scope. No PRODUCT/ROADMAP product
  edits (unlike ADR-002).
- **Spec edits this ADR drives** (applied in this PR, atomically with acceptance):
  - `CLAUDE.md` §1.9: add two rows to the verification matrix — (a) "SwiftUI view
    add/change → Layer-0 lifecycle review checklist (ADR-003) + `make test`"; (b)
    "Multi-surface navigation / stage-exit smoke → Layer-1 simulator smoke (XCUITest +
    `ios-simulator-skill`), per ADR-003." The rows **reference** ADR-003 for the
    checklist; they do not inline it (one source of truth — the checklist lives here).
  - `CLAUDE.md` §1.4: a one-line pointer that the Stage-4 5-tab smoke flow is run via
    the Layer-1 tooling (ADR-003). The flow definition itself is unchanged.
  - No change to §1.7 wording (Layer 0 references it; the wiring checklist stands).
- **v1.0-personal date impact:** **none.** Layer 0 is free; Layer 1 is absorbed into
  the S10 / Stage-4 slices that already mandate the smoke flow; Layer 2 is on-demand.

## Implementation

- **Layer 0 (follow-on change, this sprint — NOT in this PR):** mirror the checklist
  into `.claude/skills/slice-pipeline/SKILL.md` as a "UI lifecycle review (Layer 0,
  ADR-003)" sub-section that **cites** this ADR + CLAUDE.md §1.7 / §1.4 / §1.9 by
  number (does not restate them). Verified as a skill change (CLAUDE.md §1.9 skill
  row: manual review + trigger self-test).
- **Layer 1 (S10 CONTRACT, then Stage-4 CONTRACT):** the S10 CORE-root slice's
  CONTRACT pins the XCUITest target/scheme + an initial launch→navigate→screenshot
  smoke over the surfaces S10 actually ships. The **full CLAUDE.md §1.4 5-tab flow
  runner is owned by the Stage-4 CONTRACT** (all five tabs exist only at Stage 4) —
  not pre-pinned here.
- **Layer 2 (on demand):** when a view's state→structure logic first regresses past
  Layers 0–1, a CONTRACT adds `ViewInspector` (SHA-pinned, test-target only,
  supply-chain-inventoried per sprint item #5) plus structural tests for that surface.
- CONTRACT location (when worker dispatched): per slice above. **This ADR ships no
  production code.**

## Review

- Codex review round 1 (`Skill(codex:rescue)`, fresh): **APPROVE WITH CHANGES** —
  5 IMPORTANT (findings 1, 3, 4, 5, 7) + 2 NIT (2, 6). Applied: (1) replaced the §1.4
  5-tab-flow paraphrase in Context with a `CLAUDE.md §1.4` citation (dropped action
  verbs were drift); (2) qualified bare `§4` / `§9` as `CLAUDE.md §4` / `§9`; (3)
  reworded Layer-0 skill codification as a deferred follow-on (this ADR is the
  checklist's home until the skill mirrors it; the diff touches only this ADR +
  `CLAUDE.md`); (4) scoped the S10 CONTRACT to an initial smoke, moving the full §1.4
  5-tab runner to the Stage-4 CONTRACT (all five tabs exist only at Stage 4); (5)
  rescoped the Layer-0 `@Environment` item to store/VM construction; (7) flipped
  Status `proposed` → `accepted` for a durable committed state. Finding 6 (ADR-003
  numbering) needed no change.
- Codex review round 2 (`Skill(codex:rescue)`, resumed): confirmed findings 2–5
  resolved; reopened two residuals — a remaining inline §1.7 quote in Context (finding
  1) and a Status-vs-Review contradiction (finding 7). Both fixed: Context now
  references §1.7 without quoting its checklist items; the Review owner line no longer
  hedges against the `accepted` status.
- Codex review round 3 (`Skill(codex:rescue)`, resumed): **APPROVE** — both residuals
  resolved, no new issues.
- Gemini review (owner-triggered, PR #16): 4 MEDIUM, all the same class — leaked
  `[[...]]` memory wikilinks (private agent-memory cross-links that do not resolve in
  the repo) left in the prose. All four removed and rephrased as plain rationale; the
  underlying principles (cite-don't-restate, don't-one-shot-infra) are kept inline.
  Codex's three rounds had not flagged these.
- Lead approval: 2026-05-30.
- Owner: ratifies this ADR by merging the PR; per the locked cadence the owner runs
  `/gemini review` before merging.

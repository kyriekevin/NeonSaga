---
name: slice-pipeline
description: Use when running a NeonSaga feature slice or any production/infra PR through the phased pipeline — starting a slice (S7, S8, "next feature", "build X"), writing a CONTRACT, dispatching the green worker, handling a Codex/Gemini review, or opening a PR. The executable checklist for CLAUDE.md §6, plus the lessons that cost real fix-commits. Triggers on "start/run the slice", "open a PR", "dispatch the worker", "handle the review", "what's the next phase".
---

# NeonSaga slice pipeline — executable checklist

This skill is the **runbook** for the pipeline. The **canonical definition** lives
in `CLAUDE.md` §6 (phase table), §1.1 (CONTRACT), §1.2 (red/green), §1.9
(verification matrix). Do NOT fork those here — when they change, they win. This
file adds: the per-phase actions, who reviews, and the **sedimented gotchas** that
already cost fix-commits.

## The iron rule

Every production slice runs the full §6 pipeline and **STOPS for owner merge**
(locked cadence — run to PR, never self-merge, never push to `main`). Skip the
pipeline ONLY for changes < ~30 LOC with no architectural decision (typos,
mechanical renames, dead-code removal).

**Scope of "production":** touches `NeonSagaCore/Sources/` or `NeonSaga/`. Those
get red:/green: commit discipline (§1.2). Docs (`*.md`), pure config
(`project.yml`, `Makefile`, `Package.swift`), assets, **skills/agents/hooks
infra**, and ADRs are exempt from red:/green: — but substantive ones (> ~30 lines
or spec-adjacent) STILL get a Codex review before PR (a docs PR once self-skipped
review and Codex caught a real factual error).

## Roles & models (§6)

- **Lead = Opus** (this agent): planning, CONTRACT, RED tests, integration,
  verification, PR hygiene, and **dispatching all reviews**.
- **Worker = Sonnet** (`neonsaga-green-worker` subagent): GREEN implementation only,
  in an isolated worktree. **Workers may NOT trigger Codex/Gemini reviews** — only
  lead or owner does.
- **Reviewers:** Codex (contract / tests / diff, via `Skill(codex:rescue)`),
  Gemini (auto on PR, owner triggers `/gemini review`).

## Phases (run in order; each gate must pass before the next)

### 1b-contract
1. `git worktree add` an isolated worktree on a feature branch (NOT the main
   checkout — edits to the wrong tree cost a cp/restore cleanup).
2. Write `CONTRACT.md` in the worktree from `docs/templates/CONTRACT.md` (14
   sections; fill Goal / Scope / Out-of-scope / interfaces / **failing tests by
   name** / source refs §1.5 / Plan B). The CONTRACT is **worktree-local, never
   committed** (the `forbidden-paths` hook + `.gitignore` enforce this).
3. **Codex contract review** (contract-only). Worker cannot write code until the
   CONTRACT is Codex-reviewed AND lead-approved.

### 1b-tests
4. Write the RED tests against the contract. Location by §1.9: pure logic →
   `NeonSagaCore/Sources/NeonSagaCoreTests/main.swift` (register new test files in
   `main.swift` — the custom runner does NOT auto-discover); SwiftData/SwiftUI →
   `NeonSagaTests/`.
   - **Compile-order trap:** match the existing types' init **arg order** in red
     tests — Swift enforces it, and the error stays masked until the under-test
     type compiles (cost a fix-commit in S3).
5. Confirm RED for the **right reason** (feature missing, not a typo). `red:` commit.
6. **Codex tests review** (tests-only: assertions, structure, determinism).

### 2 — worker GREEN
7. Dispatch the `neonsaga-green-worker` subagent with ONLY the per-slice delta
   (its standing context — two-layer split, don't-touch-tests, verify matrix,
   return-diff-not-review — is baked into the agent def, so the prompt stays small).
8. Worker returns a diff + the `N passed, M failed` line. `green:` commit — must
   **not** modify the test file (§1.2).

### 2b — diff review
9. Lead **mechanical** check only (§6): file scope, `make verify` green,
   `git status` sanity. No substantive content review by the lead.
10. **Codex diff review** (diff vs contract). Apply fixes as **new** commits
    (prefer new over amend). Re-run the relevant `make` gate after each fix.

### 3 — verify + PR
11. Run the verification matrix row for the change scope (§1.9) — when it crosses
    the core↔app boundary, `make verify-full`. Report the pass/fail summary line.
12. Push the feature branch (never `main`). Open the PR with a scoped body. **STOP
    for owner merge.**

### Post-PR — Gemini
13. Owner triggers `/gemini review` (Gemini does NOT auto-review on push here).
    For each finding: **verify the finding, its PREMISE, AND its suggested fix on
    the merits before applying** — Gemini is fallible both ways. Apply correct
    self-contained findings (re-run `make verify-full` after); reject wrong ones
    with evidence (it re-raises unchanged findings every push — keep the same
    rationale). Examples of real rejections: a false `min/max(NaN)` claim; "pre-commit
    passes deleted files" (false — `--diff-filter=ACMRTUXB` excludes D). Don't paste
    a fix verbatim — re-derive and re-verify (a suggested fix once regressed a test).

### Post-merge — retrospective
14. `git fetch --prune` → `git checkout main` → `git merge --ff-only` → delete the
    feature branch → confirm single clean worktree.
15. **复盘 (every PR):** route each lesson to the right container — memory / this
    skill / the worker agent / a hook / an eval. Seed once, evolve continuously;
    don't one-shot infra.

## Dispatching Codex review (the structure that works)

`Skill(codex:rescue)` first (higher-quality built-in prompt); Bash `codex exec`
only if the Skill stalls > 15 min. Prompt structure: **state the goal → numbered
audit items → output format (verdict + numbered findings with BLOCKING/IMPORTANT/
NIT severity) → "no need to fix anything — just review."** `--fresh` for a new
topic, `--resume` to continue a thread (lets Codex check your impl against its own
prior verdict). Independent reviews may run in parallel; a single slice's review
rounds (contract → tests → diff) are a dependency chain and stay sequential.

## Gate truth (don't get false-greened)

- Authoritative lint/test gate = **`make hooks` / `make verify`**, never a
  `git status`-derived file list. `swift format lint` **without `--strict` only
  warns and exits 0** (false green). Run `make install-hooks` once per clone so
  `git commit` runs the gate.
- `respectsExistingLineBreaks: true` → the formatter won't wrap hand-written long
  lines; wrap manually to ~100 col.
- **Pattern-based guard scripts** (pre-commit hooks that grep/awk source): write
  the **adversarial bad/good fixture matrix FIRST** (attributes, comments, string
  literals, nested/unbalanced parens, multiline, lookalikes) — a naive guard takes
  several review rounds, and each reviewer catches different gaps.

## Verification of THIS skill

Skills are docs (§1.9): manual review + a trigger self-test on a sample task. No
build step. Mirror to Codex via `.agents/skills/<name>` (relative symlink, tracked).

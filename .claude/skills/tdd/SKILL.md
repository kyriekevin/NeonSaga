---
name: tdd
description: Use when adding any function, feature, bugfix, or refactor in NeonSaga. Write a failing test first, run it, confirm RED, then write minimum code to pass. Triggers on any code change to NeonSagaCore, NeonSaga app target, or NeonSagaTests — also when the user mentions TDD, test-driven, red/green/refactor, "add tests", "write tests for X". The user (project owner) is not a Swift native speaker, so tests are their primary correctness signal — never skip them.
---

# TDD — The Iron Law

```
NO PRODUCTION CODE IN NEONSAGA WITHOUT A FAILING TEST FIRST
```

The NeonSaga owner does not read Swift fluently. Tests are the **only** way they can verify your code works correctly. Skipping TDD means asking them to trust LLM output blindly — that's how subtle bugs ship.

See also `CLAUDE.md` §1.2 (red+green PR-level discipline) and §1.9 (verification matrix).

## When this applies

- Adding any function, struct, class, actor, protocol → TDD required
- Bug fix → write a test that reproduces the bug first, then fix
- Refactor → keep existing tests green; add tests for any new behavior introduced
- Adding a new module/file → start with its first test

## When this does NOT apply (still requires explicit user nod)

- One-off probes / throwaway scripts (e.g., Stage 1 killer-edge spike per ROADMAP §2)
- Generated boilerplate (xcodegen output, asset catalogs)
- One-time genesis bootstrap (custom test-runner harness, minimal `@main` app shell, SwiftPM/XcodeGen skeleton — can't be test-driven before they exist; first real red/green lands with the first Stage 1 feature)
- Pure config (project.yml, .entitlements, Info.plist properties)
- Pure documentation (Markdown)

If unsure: assume TDD applies.

## The Red-Green-Refactor cycle

### 1. RED — Write ONE failing test

Add the test to the right target (per `CLAUDE.md` §1.9 verification matrix):

| Code being tested | Test location | Run with |
|---|---|---|
| Pure Swift logic (enums, protocols, structs, Keychain, formatters, prompt builders) | `NeonSagaCore/Sources/NeonSagaCoreTests/main.swift` | `make test-core` |
| `@Model` SwiftData classes | `NeonSagaTests/` (XCTest) — **requires full Xcode** | `make test` |
| SwiftUI views / app integration | `NeonSagaTests/` (XCTest) | `make test` |

Then **run** the test and **confirm RED**:
- Test fails (does not error from typo / missing import)
- Failure message identifies the missing thing
- The reason for failure is "feature/function doesn't exist yet" — not anything else

If RED happens for the wrong reason (typo in test, missing import), fix the test until RED happens for the **right** reason before moving on.

**PR-level discipline (`CLAUDE.md` §1.2):** RED commit precedes GREEN commit. Commit message: `red: <feature> — failing test`. The implementation commit (`green: <feature> — impl`) may not modify the test file.

### 2. GREEN — Smallest possible code

- Write the absolute minimum needed to pass the test
- Resist "while I'm here" additions — those need their own tests first
- Run tests again, confirm all green
- The diff for GREEN should be small and obvious

### 3. REFACTOR — Optional, only after green

- Now tests are green → safe to rename, dedupe, extract helpers
- Do NOT add behavior in this step
- Tests stay green throughout

## How to report to the user

The user can't read Swift but reads test counts and the pass/fail summary. Every cycle, surface this concisely:

After RED (expected):
> 🔴 (expected) `APIKeyStore` doesn't exist yet — writing impl next.

After GREEN:
> 🟢 38 passed, 0 failed. New: `APIKeyStore` round-trip + provider isolation.

After REFACTOR:
> 🟢 38 passed, 0 failed (after extracting `keychainQuery` helper).

Do not bury the count. The user is anchoring on it.

## Anti-patterns — STOP and restart if you catch any

- ❌ Writing implementation before writing the test
- ❌ Tests that pass on the first run (the test isn't testing anything new)
- ❌ "This is too simple to need a test" — most subtle bugs hide in `it looks obvious`
- ❌ "I'll add tests after I see it work"
- ❌ Writing every test then every impl in one go (acceptable in batch only when the user has approved — see strict mode below)
- ❌ Modifying the test until it passes ("oh, that wasn't quite what I meant") — instead, fix the impl or write a new test
- ❌ Deleting a failing test because "it's not testing what I want anymore" without writing a replacement

If you catch yourself doing any of these: stop, delete the offending code, restart the cycle.

## Strict vs. relaxed mode

**Strict (default for this project):** one test → red → impl → green → next test. The user sees the RED → GREEN transition for each behavior.

**Relaxed (only when user explicitly approves):** write a batch of related tests, run once for RED, write batch of impls, run once for GREEN. Acceptable when:
- The user has explicitly said "do them in batch"
- The tests are clearly mechanical/repetitive (e.g., raw value checks for an enum's 5 cases)

When in doubt → strict.

## What counts as a "test"

For NeonSagaCore (custom runner):
```swift
group("Some module — what's being checked")
expect("specific behavior described") { /* return Bool */ }
// async variant available:
await expectAsync("async behavior") { /* return Bool */ }
```

For iOS XCTest target (once Xcode runtime ready):
```swift
final class FooTests: XCTestCase {
    func testSpecificBehavior() throws { /* XCTAssert... */ }
}
```

**Good test qualities:**
- One concept per test (single `expect` call ideally, or one logical assertion group)
- Name describes **behavior**, not implementation
- Uses real types where possible (avoid mocking SwiftData / Keychain unless absolutely needed)
- Deterministic — no time/random/network dependencies unless intentional

## File layout reminder

```
NeonSagaCore/
├── Package.swift
├── Sources/
│   ├── NeonSagaCore/          ← production code goes here (or new feature folders)
│   └── NeonSagaCoreTests/
│       └── main.swift         ← all NeonSagaCore tests live here for now
```

When tests in `main.swift` get unwieldy, split into multiple files by feature. Each non-main file defines `@MainActor func runFooTests() [async]` and `main.swift` calls them. **Remember `CLAUDE.md` §1.7 wiring completeness:** any new test file must be registered in `main.swift` (custom runner does NOT auto-discover).

## Why the custom runner (not XCTest / swift-testing)

Apple's Command Line Tools ship `XCTest.framework` and `Testing.framework` incomplete (`lib_TestingInterop.dylib` missing from dyld path). The custom runner sidesteps both. When the iOS app target's XCTest harness is live, use XCTest there. See `docs/TOOLCHAIN.md` once that doc is added.

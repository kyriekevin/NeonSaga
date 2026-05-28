import Foundation
import NeonSagaCore

// MARK: - Custom test runner
//
// `NeonSagaCoreTests` is an `.executableTarget`, NOT XCTest. Apple's CLT ships
// an incomplete XCTest/Testing stack (missing `lib_TestingInterop.dylib`), so
// `swift test` cannot host this layer (CLAUDE.md §4). This runner uses
// top-level code (which is `@MainActor`-isolated) + `@MainActor` helpers, and
// exits non-zero on the first failed expectation. To narrow scope while
// debugging, comment out unrelated `group(...)` calls.

@MainActor
private enum Runner {
    static var passCount = 0
    static var currentGroup = "<root>"
}

@MainActor
func group(_ name: String, _ body: () -> Void) {
    Runner.currentGroup = name
    body()
}

@MainActor
func group(_ name: String, _ body: () async -> Void) async {
    Runner.currentGroup = name
    await body()
}

@MainActor
func expect(
    _ condition: Bool,
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    if condition {
        Runner.passCount += 1
    } else {
        print("❌ FAIL [\(Runner.currentGroup)] \(message)  (\(file):\(line))")
        print("   \(Runner.passCount) passed before this failure")
        exit(1)
    }
}

@MainActor
func expectAsync(
    _ condition: @autoclosure () async -> Bool,
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
) async {
    let value = await condition()
    expect(value, message, file: file, line: line)
}

// MARK: - Test groups
//
// Genesis smoke test only — proves the runner links `NeonSagaCore` and the
// expect/exit mechanism works. Real groups (HealthSnapshot.derive, Recovery
// math, cross-domain rules, …) land per the Stage 1 CONTRACT.

group("genesis-smoke") {
    expect(NeonSagaCore.version == "0.0.0-genesis", "NeonSagaCore.version seed reachable")
    expect(1 + 1 == 2, "runner arithmetic sanity")
}

// MARK: - Stage 1 · Slice 1 — HEALTH domain (RED)
//
// Asserts the interface the green: impl must satisfy: Level.of, SubStat,
// SubStatValue, LevelUp.detect, HealthStat. Formulas from PRODUCT §6/§7.

group("health-lv-math") {
    // Per-value LV = floor((value / 100) × 99) + 1, clamped to LV 1–100 (PRODUCT §7).
    expect(Level.of(0) == 1, "Level.of(0) == 1")
    expect(Level.of(1) == 1, "Level.of(1) == 1")
    expect(Level.of(1.5) == 2, "Level.of(1.5) == 2 (LV-1→LV-2 threshold ≈1.0101, not ≥2)")
    expect(Level.of(50) == 50, "Level.of(50) == 50")
    expect(Level.of(99) == 99, "Level.of(99) == 99")
    expect(Level.of(100) == 100, "Level.of(100) == 100")
    expect(Level.of(149) == 100, "Level.of(149) caps at LV 100")
    expect(Level.of(-5) == 1, "Level.of(-5) floors at LV 1")
    expect(
        SubStatValue(.fatigue, value: 60).level == 60, "SubStatValue.level recomputes from value")
    expect(SubStatValue(.hunger, value: 30).level == 30, "SubStatValue(.hunger).level == 30")
    expect(SubStatValue(.strength, value: 80).level == 80, "SubStatValue(.strength).level == 80")
}

group("health-levelup-detect") {
    // LevelUp.detect returns a crossing iff newLevel > oldLevel, else nil.
    expect(LevelUp.detect(from: 40, to: 60)?.oldLevel == 40, "40→60 reports oldLevel 40")
    expect(LevelUp.detect(from: 40, to: 60)?.newLevel == 60, "40→60 reports newLevel 60")
    expect(LevelUp.detect(from: 60, to: 60) == nil, "equal LV → no crossing")
    expect(
        LevelUp.detect(from: 50.0, to: 50.4) == nil, "value moved but LV unchanged → no crossing")
    expect(LevelUp.detect(from: 60, to: 40) == nil, "decrease → no crossing")
}

group("health-aggregate") {
    // HEALTH value = clamp(avg of values, 0, 100); LV = floor(avg of sub-stat LVs) (PRODUCT §6/§7).
    expect(HealthStat.value(hunger: 60, fatigue: 60, strength: 60) == 60, "HEALTH value = avg = 60")
    expect(
        HealthStat.level(hunger: 60, fatigue: 60, strength: 60) == 60,
        "HEALTH LV = floor(avg sub-LVs) = 60")
    expect(
        HealthStat.value(hunger: 120, fatigue: 100, strength: 100) == 100,
        "HEALTH value clamps to 100")
    expect(
        HealthStat.level(hunger: 1, fatigue: 1, strength: 2) == 1,
        "HEALTH LV = floor(avg LVs)=1, not LV(avg value)=2")
    expect(
        HealthStat.value(hunger: -20, fatigue: 0, strength: 0) == 0,
        "HEALTH value lower-clamps to 0")
    expect(
        HealthStat.level(hunger: 1.5, fatigue: 1.5, strength: 1.5) == 2,
        "HEALTH LV uses floor(avg of LVs)=2, not floor(avg of values)=1")
}

// MARK: - Summary
//
// Fail-fast above means reaching here implies every expectation passed.
print("✅ \(Runner.passCount) passed, 0 failed")

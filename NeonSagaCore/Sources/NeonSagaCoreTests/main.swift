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

// MARK: - Stage 1 · Slice 2 — HealthSnapshot + HealthDataSource (RED)
//
// Asserts the HEALTH data-bridge contract (S2 CONTRACT). Property-based
// (bounds / finiteness / monotonicity / identity / delegation) so S3/S4 can
// refine the Stage-1 baseline curves without breaking these tests.

private struct FakeHealthDataSource: HealthDataSource {
    let stored: HealthMetrics
    func latestMetrics() async -> HealthMetrics { stored }
}

private let s2Epoch = Date(timeIntervalSince1970: 1_700_000_000)

group("health-snapshot-derive") {
    // RB #1 — partial init: each omitted field is nil (omitted ≠ 0).
    let partial = HealthMetrics(hrvRMSSD: 45)
    expect(partial.hrvRMSSD == 45, "supplied field is set")
    expect(
        partial.restingHeartRate == nil && partial.sleepEfficiency == nil
            && partial.activeWorkoutEnergyKilocalories == nil,
        "partial init leaves the other 3 fields nil")
    let blank = HealthMetrics()
    expect(
        blank.restingHeartRate == nil && blank.hrvRMSSD == nil && blank.sleepEfficiency == nil
            && blank.activeWorkoutEnergyKilocalories == nil, "no-arg init is all-nil")

    // RB #2 — derive retains capturedAt + metrics verbatim.
    let m = HealthMetrics(
        restingHeartRate: 55, hrvRMSSD: 45, sleepEfficiency: 0.9,
        activeWorkoutEnergyKilocalories: 300)
    let snap = HealthSnapshot.derive(from: m, at: s2Epoch)
    expect(snap.capturedAt == s2Epoch, "derive retains capturedAt")
    expect(snap.metrics == m, "derive retains metrics verbatim")

    // RB #3 — correct SubStat identity on each derived sub-stat.
    expect(snap.hunger.substat == .hunger, "hunger sub-stat identity")
    expect(snap.fatigue.substat == .fatigue, "fatigue sub-stat identity")
    expect(snap.strength.substat == .strength, "strength sub-stat identity")

    // RB #4 + #9 — all-nil metrics → finite, clamped 0...100 (NaN-guard).
    let empty = HealthSnapshot.derive(from: HealthMetrics(), at: s2Epoch)
    expect(
        empty.fatigue.value.isFinite && (0...100).contains(empty.fatigue.value),
        "all-nil FATIGUE finite in 0...100")
    expect(
        empty.strength.value.isFinite && (0...100).contains(empty.strength.value),
        "all-nil STRENGTH finite in 0...100")
    expect(
        empty.hunger.value.isFinite && (0...100).contains(empty.hunger.value),
        "all-nil HUNGER finite in 0...100")

    // RB #4 — pathological inputs (NaN / inf / huge / negative) → clamped finite.
    let nan = HealthSnapshot.derive(
        from: HealthMetrics(
            restingHeartRate: .nan, hrvRMSSD: .nan, sleepEfficiency: .nan,
            activeWorkoutEnergyKilocalories: .nan), at: s2Epoch)
    expect(
        nan.fatigue.value.isFinite && (0...100).contains(nan.fatigue.value),
        "NaN inputs → FATIGUE finite in 0...100")
    expect(
        nan.strength.value.isFinite && (0...100).contains(nan.strength.value),
        "NaN inputs → STRENGTH finite in 0...100")
    let extreme = HealthSnapshot.derive(
        from: HealthMetrics(
            hrvRMSSD: .infinity, sleepEfficiency: 9,
            activeWorkoutEnergyKilocalories: 1_000_000), at: s2Epoch)
    expect((0...100).contains(extreme.fatigue.value), "huge/inf inputs → FATIGUE ≤ 100")
    expect((0...100).contains(extreme.strength.value), "huge inputs → STRENGTH ≤ 100")
    let negative = HealthSnapshot.derive(
        from: HealthMetrics(
            hrvRMSSD: -50, sleepEfficiency: -1, activeWorkoutEnergyKilocalories: -100),
        at: s2Epoch)
    expect((0...100).contains(negative.fatigue.value), "negative inputs → FATIGUE ≥ 0")
    expect((0...100).contains(negative.strength.value), "negative inputs → STRENGTH ≥ 0")

    // RB #5 — FATIGUE strictly increases with HRV (other inputs held nil).
    let loHRV = HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 0), at: s2Epoch)
    let hiHRV = HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 100), at: s2Epoch)
    expect(loHRV.fatigue.value < hiHRV.fatigue.value, "FATIGUE strictly increases with HRV")

    // RB #6 — FATIGUE strictly increases with sleep efficiency (others nil).
    let loSleep = HealthSnapshot.derive(from: HealthMetrics(sleepEfficiency: 0), at: s2Epoch)
    let hiSleep = HealthSnapshot.derive(from: HealthMetrics(sleepEfficiency: 1), at: s2Epoch)
    expect(loSleep.fatigue.value < hiSleep.fatigue.value, "FATIGUE strictly increases with sleep")

    // RB #7 — FATIGUE strictly increases with workout energy (others nil; workout → FATIGUE+X).
    let loWk = HealthSnapshot.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: 0), at: s2Epoch)
    let hiWk = HealthSnapshot.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: 600), at: s2Epoch)
    expect(loWk.fatigue.value < hiWk.fatigue.value, "FATIGUE strictly increases with workout")

    // RB #8 — STRENGTH strictly increases with workout energy.
    expect(loWk.strength.value < hiWk.strength.value, "STRENGTH strictly increases with workout")

    // RB #13 — STRENGTH depends ONLY on workout energy (PRODUCT §9): invariant to each
    // non-workout input varied INDIVIDUALLY (single-var, so a canceling term can't hide).
    let strBase = HealthSnapshot.derive(
        from: HealthMetrics(
            restingHeartRate: 60, hrvRMSSD: 20, sleepEfficiency: 0.5,
            activeWorkoutEnergyKilocalories: 300), at: s2Epoch)
    let strVaryHRV = HealthSnapshot.derive(
        from: HealthMetrics(
            restingHeartRate: 60, hrvRMSSD: 90, sleepEfficiency: 0.5,
            activeWorkoutEnergyKilocalories: 300), at: s2Epoch)
    let strVarySleep = HealthSnapshot.derive(
        from: HealthMetrics(
            restingHeartRate: 60, hrvRMSSD: 20, sleepEfficiency: 0.95,
            activeWorkoutEnergyKilocalories: 300), at: s2Epoch)
    let strVaryRHR = HealthSnapshot.derive(
        from: HealthMetrics(
            restingHeartRate: 40, hrvRMSSD: 20, sleepEfficiency: 0.5,
            activeWorkoutEnergyKilocalories: 300), at: s2Epoch)
    expect(strVaryHRV.strength.value == strBase.strength.value, "STRENGTH invariant to HRV alone")
    expect(
        strVarySleep.strength.value == strBase.strength.value, "STRENGTH invariant to sleep alone")
    expect(strVaryRHR.strength.value == strBase.strength.value, "STRENGTH invariant to RHR alone")

    // RB #10 — HUNGER neutral placeholder = 50.0, independent of metrics (incl. NaN/inf).
    expect(snap.hunger.value == 50.0, "HUNGER == 50.0 placeholder")
    expect(empty.hunger.value == 50.0, "HUNGER == 50.0 even with no metrics")
    expect(nan.hunger.value == 50.0, "HUNGER == 50.0 under NaN metrics")
    expect(extreme.hunger.value == 50.0, "HUNGER == 50.0 under inf/huge metrics")
    expect(negative.hunger.value == 50.0, "HUNGER == 50.0 under negative metrics")

    // RB #11 — HEALTH aggregate delegates to HealthStat over derived sub-stats.
    expect(
        snap.healthValue
            == HealthStat.value(
                hunger: snap.hunger.value, fatigue: snap.fatigue.value,
                strength: snap.strength.value), "healthValue delegates to HealthStat.value")
    expect(
        snap.healthLevel
            == HealthStat.level(
                hunger: snap.hunger.value, fatigue: snap.fatigue.value,
                strength: snap.strength.value), "healthLevel delegates to HealthStat.level")
}

// RB #12 — async seam: source → latestMetrics() → derive == direct derive.
await group("health-snapshot-source") {
    let m = HealthMetrics(
        restingHeartRate: 55, hrvRMSSD: 45, sleepEfficiency: 0.9,
        activeWorkoutEnergyKilocalories: 300)
    let source = FakeHealthDataSource(stored: m)
    let fetched = await source.latestMetrics()
    let viaSource = HealthSnapshot.derive(from: fetched, at: s2Epoch)
    let direct = HealthSnapshot.derive(from: m, at: s2Epoch)
    expect(viaSource.capturedAt == direct.capturedAt, "source round-trip capturedAt matches")
    expect(viaSource.metrics == direct.metrics, "source round-trip metrics match direct derive")
    expect(
        viaSource.fatigue.value == direct.fatigue.value,
        "source round-trip FATIGUE matches direct derive")
    expect(
        viaSource.strength.value == direct.strength.value,
        "source round-trip STRENGTH matches direct derive")
    expect(
        viaSource.hunger.value == direct.hunger.value,
        "source round-trip HUNGER matches direct derive")
}

// MARK: - Summary
//
// Fail-fast above means reaching here implies every expectation passed.
print("✅ \(Runner.passCount) passed, 0 failed")

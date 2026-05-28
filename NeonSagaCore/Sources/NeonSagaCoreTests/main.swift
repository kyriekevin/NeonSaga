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

    // RB #14 (Gemini PR#3 G1) — missing inputs are EXCLUDED from the FATIGUE average,
    // not counted as 0; all-missing → neutral 50 (a missing sample ≠ worst state).
    expect(empty.fatigue.value == 50.0, "all-missing FATIGUE → neutral 50, not 0")
    let twoPresent = HealthSnapshot.derive(
        from: HealthMetrics(hrvRMSSD: 80, sleepEfficiency: 0.8), at: s2Epoch)
    let threeZeroWk = HealthSnapshot.derive(
        from: HealthMetrics(
            hrvRMSSD: 80, sleepEfficiency: 0.8, activeWorkoutEnergyKilocalories: 0), at: s2Epoch)
    expect(
        twoPresent.fatigue.value > threeZeroWk.fatigue.value,
        "absent workout excluded from FATIGUE avg, not counted as a 0 reading")

    // RB #15 (Gemini PR#3 round 2) — a finite input whose transform OVERFLOWS to
    // non-finite is treated as an invalid/missing signal (excluded), preserving the
    // finite guarantee — never clamped to a bound nor propagated.
    let overflow = HealthSnapshot.derive(
        from: HealthMetrics(sleepEfficiency: .greatestFiniteMagnitude), at: s2Epoch)
    expect(
        overflow.fatigue.value == 50.0,
        "transform-overflow sleep excluded → all-missing FATIGUE 50, not clamped to 100")
    expect(overflow.fatigue.value.isFinite, "transform-overflow → FATIGUE still finite")

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

// MARK: - Stage 1 · Slice 3 — Recovery score (RED)
//
// Recovery 0–100 + RED/YELLOW/GREEN bands from a HealthSnapshot's raw HRV / RHR /
// sleep, baseline-normalized vs a 28-day HRV window. Property-based + anti-cheat
// (strict per-input contribution, band reachability, no-double-count). S3 CONTRACT.

private func recoverySnap(_ metrics: HealthMetrics) -> HealthSnapshot {
    HealthSnapshot.derive(from: metrics, at: s2Epoch)
}

@MainActor
private func recoveryValue(_ result: RecoveryResult) -> Double {
    if case .scored(let value, _) = result { return value }
    expect(false, "expected .scored, got .calibrating (monotonic/neutral inputs must score)")
    return -1
}

private func recoveryBand(_ result: RecoveryResult) -> RecoveryBand? {
    if case .scored(_, let band) = result { return band }
    return nil
}

group("recovery-score") {
    let baselineVaried = (0..<28).map { 40.0 + Double($0) }  // 28 samples, mean 53.5, std > 0
    let baselineZeroVar = Array(repeating: 50.0, count: 28)  // std == 0
    let baselineFew = Array(repeating: 50.0, count: 10)  // < 14 → calibrating

    // RB #1 — RecoveryResult / RecoveryBand are Equatable.
    expect(
        RecoveryResult.calibrating(daysOfData: 5) == .calibrating(daysOfData: 5),
        "RecoveryResult Equatable")
    expect(RecoveryBand.green != RecoveryBand.red, "RecoveryBand Equatable")

    // RB #2 — < 14 finite baseline samples → calibrating(daysOfData: finite count).
    expect(
        Recovery.score(for: recoverySnap(HealthMetrics(hrvRMSSD: 55)), hrvBaseline: baselineFew)
            == .calibrating(daysOfData: 10),
        "fewer than 14 baseline samples → calibrating(10)")
    expect(
        Recovery.score(
            for: recoverySnap(HealthMetrics(hrvRMSSD: 55)),
            hrvBaseline: [50, 50, 50, .nan, .infinity]) == .calibrating(daysOfData: 3),
        "non-finite baseline entries ignored; 3 finite < 14 → calibrating(3)")

    // RB #3 — missing today-HRV → calibrating even with a full baseline.
    expect(
        Recovery.score(
            for: recoverySnap(HealthMetrics(restingHeartRate: 60)), hrvBaseline: baselineVaried)
            == .calibrating(daysOfData: 28),
        "missing today-HRV → calibrating despite full baseline")
    expect(
        Recovery.score(
            for: recoverySnap(HealthMetrics(hrvRMSSD: .nan)), hrvBaseline: baselineVaried)
            == .calibrating(daysOfData: 28),
        "NaN today-HRV → calibrating despite full baseline")
    expect(
        Recovery.score(
            for: recoverySnap(HealthMetrics(hrvRMSSD: .infinity)), hrvBaseline: baselineVaried)
            == .calibrating(daysOfData: 28),
        "infinite today-HRV → calibrating despite full baseline")

    // RB #4 — >= 14 samples + finite HRV → scored, value finite & in 0...100.
    let scored = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.9)),
        hrvBaseline: baselineVaried)
    if case .scored(let value, _) = scored {
        expect(value.isFinite && (0...100).contains(value), "scored value finite & in 0...100")
    } else {
        expect(false, "expected .scored for full baseline + finite HRV")
    }

    // RB #5 — zero-variance baseline (std == 0) → scored, finite (no NaN).
    let zeroVar = Recovery.score(
        for: recoverySnap(HealthMetrics(hrvRMSSD: 60)), hrvBaseline: baselineZeroVar)
    if case .scored(let value, _) = zeroVar {
        expect(
            value.isFinite && (0...100).contains(value),
            "zero-variance baseline → finite score, no NaN")
    } else {
        expect(false, "expected .scored for zero-variance baseline, not calibrating")
    }

    // RB #5b — under zero-variance baseline the HRV-variance term is NEUTRAL: today-HRV does
    // not change Recovery (forbids a std=1 fallback that lets HRV dominate under zero variance).
    let zvLoHRV = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 30, sleepEfficiency: 0.8)),
            hrvBaseline: baselineZeroVar))
    let zvHiHRV = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 90, sleepEfficiency: 0.8)),
            hrvBaseline: baselineZeroVar))
    expect(zvLoHRV == zvHiHRV, "zero-variance baseline → HRV term neutral (today-HRV irrelevant)")

    // RB #5c (Gemini PR#4 HIGH) — a NEAR-zero-variance baseline (0 < std < 1.0 ms) is likewise
    // treated as no HRV-variance signal: today-HRV must not swing the score (else a tiny std
    // blows the z-score to the clamp rails on measurement noise).
    let baselineNearZeroVar = Array(repeating: 50.0, count: 27) + [50.5]  // std ≈ 0.09 ms
    let nzvLoHRV = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 30, sleepEfficiency: 0.8)),
            hrvBaseline: baselineNearZeroVar))
    let nzvHiHRV = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 90, sleepEfficiency: 0.8)),
            hrvBaseline: baselineNearZeroVar))
    expect(nzvLoHRV == nzvHiHRV, "near-zero-variance baseline (std < 1) → HRV term neutral")

    // RB #6 — NaN/inf in today RHR/sleep → still finite scored.
    let patho = Recovery.score(
        for: recoverySnap(
            HealthMetrics(restingHeartRate: .nan, hrvRMSSD: 55, sleepEfficiency: .infinity)),
        hrvBaseline: baselineVaried)
    if case .scored(let value, _) = patho {
        expect(
            value.isFinite && (0...100).contains(value), "NaN/inf today RHR/sleep → finite score")
    } else {
        expect(false, "expected .scored (today HRV present)")
    }

    // RB #6b — non-finite baseline entries are excluded from mean/std (scored path stays finite).
    let dirtyBaseline = baselineVaried + [.nan, .infinity, -.infinity]
    let dirty = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8)),
        hrvBaseline: dirtyBaseline)
    if case .scored(let value, _) = dirty {
        expect(
            value.isFinite && (0...100).contains(value),
            "non-finite baseline entries excluded → finite scored value")
    } else {
        expect(false, "expected .scored (28 finite baseline samples despite NaN/inf entries)")
    }
    let cleanForDirty = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8)),
        hrvBaseline: baselineVaried)
    expect(
        dirty == cleanForDirty,
        "non-finite baseline entries EXCLUDED (not coerced to 0) → same score as clean baseline")

    // RB #7 — Recovery strictly increases with today-HRV (above vs below baseline mean 53.5).
    let belowMean = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 42, sleepEfficiency: 0.8)),
            hrvBaseline: baselineVaried))
    let aboveMean = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 66, sleepEfficiency: 0.8)),
            hrvBaseline: baselineVaried))
    expect(belowMean < aboveMean, "Recovery strictly increases with today-HRV")

    // RB #7b — Recovery is BASELINE-NORMALIZED: the SAME today-HRV scores strictly HIGHER
    // against a lower-mean baseline (today above baseline) than a higher-mean baseline (today
    // below). Forbids an impl that uses absolute HRV and ignores the 28-day baseline.
    let lowMeanBaseline = (0..<28).map { 24.0 + Double($0) * 0.5 }  // mean ~30.75, std > 0
    let highMeanBaseline = (0..<28).map { 74.0 + Double($0) * 0.5 }  // mean ~80.75, std > 0
    let vsLowBaseline = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8)),
            hrvBaseline: lowMeanBaseline))
    let vsHighBaseline = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8)),
            hrvBaseline: highMeanBaseline))
    expect(
        vsLowBaseline > vsHighBaseline,
        "baseline-normalized: today=55 above a low-mean baseline scores > below a high-mean one")

    // RB #8 — Recovery strictly increases with sleep efficiency (others fixed).
    let loSleep = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.2)),
            hrvBaseline: baselineVaried))
    let hiSleep = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.95)),
            hrvBaseline: baselineVaried))
    expect(loSleep < hiSleep, "Recovery strictly increases with sleep efficiency")

    // RB #9 — Recovery strictly increases as resting HR decreases (others fixed).
    let hiRHR = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 75, hrvRMSSD: 55, sleepEfficiency: 0.8)),
            hrvBaseline: baselineVaried))
    let loRHR = recoveryValue(
        Recovery.score(
            for: recoverySnap(
                HealthMetrics(restingHeartRate: 45, hrvRMSSD: 55, sleepEfficiency: 0.8)),
            hrvBaseline: baselineVaried))
    expect(hiRHR < loRHR, "Recovery strictly increases as resting HR decreases")

    // RB #10 — band reachability: strong→GREEN, weak→RED, mid→YELLOW all reachable.
    let strong = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 42, hrvRMSSD: 90, sleepEfficiency: 1.0)),
        hrvBaseline: baselineVaried)
    let weak = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 95, hrvRMSSD: 10, sleepEfficiency: 0.05)),
        hrvBaseline: baselineVaried)
    let mid = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 60, hrvRMSSD: 54, sleepEfficiency: 0.5)),
        hrvBaseline: baselineVaried)
    expect(recoveryBand(strong) == .green, "strong recovery inputs → GREEN")
    expect(recoveryBand(weak) == .red, "weak recovery inputs → RED")
    expect(recoveryBand(mid) == .yellow, "mid recovery inputs → YELLOW")
    // value↔band consistency at the cutoffs (<34 red / [34,67) yellow / ≥67 green).
    if case .scored(let v, let b) = strong { expect(v >= 67 && b == .green, "GREEN ⇔ value ≥ 67") }
    if case .scored(let v, let b) = weak { expect(v < 34 && b == .red, "RED ⇔ value < 34") }
    if case .scored(let v, let b) = mid {
        expect((34..<67).contains(v) && b == .yellow, "YELLOW ⇔ 34 ≤ value < 67")
    }

    // RB #10b — band threshold rule pinned globally via Recovery.band(for:), independent of
    // the blend (cutoffs: <34 RED / [34,67) YELLOW / ≥67 GREEN).
    expect(Recovery.band(for: 0) == .red, "value 0 → RED")
    expect(Recovery.band(for: 33.9) == .red, "value 33.9 → RED")
    expect(Recovery.band(for: 34) == .yellow, "value 34 → YELLOW (lower cutoff inclusive)")
    expect(Recovery.band(for: 66.9) == .yellow, "value 66.9 → YELLOW")
    expect(Recovery.band(for: 67) == .green, "value 67 → GREEN (lower cutoff inclusive)")
    expect(Recovery.band(for: 100) == .green, "value 100 → GREEN")
    // RB #10c (Gemini PR#4 MEDIUM) — NaN must not fall through to .green (best state).
    expect(Recovery.band(for: .nan) == .red, "NaN value → RED (defensive, never .green)")

    // RB #11 — no double-count: vary workout energy (changes snapshot.fatigue via derive);
    // Recovery reads only HRV/RHR/sleep, so it must be unchanged.
    let noWk = Recovery.score(
        for: recoverySnap(
            HealthMetrics(
                restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8,
                activeWorkoutEnergyKilocalories: 0)), hrvBaseline: baselineVaried)
    let bigWk = Recovery.score(
        for: recoverySnap(
            HealthMetrics(
                restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8,
                activeWorkoutEnergyKilocalories: 600)), hrvBaseline: baselineVaried)
    let nilWk = Recovery.score(
        for: recoverySnap(HealthMetrics(restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.8)),
        hrvBaseline: baselineVaried)
    if case .scored = noWk {} else { expect(false, "RB#11 noWk must be .scored, not calibrating") }
    expect(noWk == bigWk, "Recovery ignores workout energy (0 vs 600) — no double-count")
    expect(noWk == nilWk, "Recovery ignores workout energy (0 vs nil) — no double-count")
}

// MARK: - Summary
//
// Fail-fast above means reaching here implies every expectation passed.
print("✅ \(Runner.passCount) passed, 0 failed")

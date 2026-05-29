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

group("daily-health-input") {
    // RB #1 — HealthMetrics partial/blank init: omitted ≠ 0 (unchanged from S2).
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

    // A >=14-sample baseline, mean 53.5, std > 1 — for baseline-relative FATIGUE.
    let baseline = (0..<28).map { 40.0 + Double($0) }

    // RB #2 — HealthSnapshot is now a metrics carrier; DailyHealthInput.derive retains capturedAt.
    let m = HealthMetrics(
        restingHeartRate: 55, hrvRMSSD: 45, sleepEfficiency: 0.9,
        activeWorkoutEnergyKilocalories: 300)
    let snap = HealthSnapshot(capturedAt: s2Epoch, metrics: m)
    expect(snap.capturedAt == s2Epoch, "HealthSnapshot retains capturedAt")
    expect(snap.metrics == m, "HealthSnapshot retains metrics verbatim")
    expect(
        DailyHealthInput.derive(from: m, hrvBaseline: baseline, at: s2Epoch).capturedAt == s2Epoch,
        "DailyHealthInput.derive retains capturedAt")

    // RB #4/#9 — all-nil metrics → finite, clamped 0...100 (empty baseline → FATIGUE calibrating).
    let empty = DailyHealthInput.derive(from: HealthMetrics(), hrvBaseline: [], at: s2Epoch)
    expect(
        empty.fatigue.isFinite && (0...100).contains(empty.fatigue),
        "all-nil FATIGUE finite in 0...100")
    expect(
        empty.strength.isFinite && (0...100).contains(empty.strength),
        "all-nil STRENGTH finite in 0...100")
    expect(
        empty.hunger.isFinite && (0...100).contains(empty.hunger),
        "all-nil HUNGER finite in 0...100")

    // FATIGUE source = HRV only (ADR-002 Decision 1). Calibrating (empty / <14 finite baseline,
    // OR nil/non-finite today-HRV) → neutral 50.
    expect(empty.fatigue == 50.0, "empty baseline → FATIGUE 50 (calibrating)")
    let fewBaseline = DailyHealthInput.derive(
        from: HealthMetrics(hrvRMSSD: 80), hrvBaseline: Array(repeating: 50.0, count: 10),
        at: s2Epoch)
    expect(fewBaseline.fatigue == 50.0, "<14 finite baseline → FATIGUE 50 (calibrating)")
    let noTodayHRV = DailyHealthInput.derive(
        from: HealthMetrics(sleepEfficiency: 0.9), hrvBaseline: baseline, at: s2Epoch)
    expect(noTodayHRV.fatigue == 50.0, "nil today-HRV → FATIGUE 50 (calibrating)")

    // FATIGUE = baseline-relative HRV reading: strictly increases with today-HRV (baseline fixed);
    // below/above the baseline mean reads </> 50.
    let loHRV = DailyHealthInput.derive(
        from: HealthMetrics(hrvRMSSD: 42), hrvBaseline: baseline, at: s2Epoch)
    let hiHRV = DailyHealthInput.derive(
        from: HealthMetrics(hrvRMSSD: 66), hrvBaseline: baseline, at: s2Epoch)
    expect(loHRV.fatigue < hiHRV.fatigue, "FATIGUE strictly increases with today-HRV")
    expect(loHRV.fatigue < 50 && hiHRV.fatigue > 50, "FATIGUE below/above baseline mean reads </> 50")

    // FATIGUE invariant to sleep AND workout (ADR-002 Decision 1: neither feeds FATIGUE anymore).
    // REPLACES the old S2 RB#6/#7 which asserted the opposite — the shipped spec violation.
    let fBaseM = HealthMetrics(
        restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.5,
        activeWorkoutEnergyKilocalories: 300)
    let fVarySleep = HealthMetrics(
        restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.95,
        activeWorkoutEnergyKilocalories: 300)
    let fVaryWk = HealthMetrics(
        restingHeartRate: 60, hrvRMSSD: 55, sleepEfficiency: 0.5,
        activeWorkoutEnergyKilocalories: 50)
    let fBase = DailyHealthInput.derive(from: fBaseM, hrvBaseline: baseline, at: s2Epoch).fatigue
    expect(
        DailyHealthInput.derive(from: fVarySleep, hrvBaseline: baseline, at: s2Epoch).fatigue
            == fBase, "FATIGUE invariant to sleep efficiency")
    expect(
        DailyHealthInput.derive(from: fVaryWk, hrvBaseline: baseline, at: s2Epoch).fatigue == fBase,
        "FATIGUE invariant to workout energy")

    // RB #8 — STRENGTH strictly increases with workout energy.
    let loWk = DailyHealthInput.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: 0), hrvBaseline: baseline, at: s2Epoch)
    let hiWk = DailyHealthInput.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: 600), hrvBaseline: baseline,
        at: s2Epoch)
    expect(loWk.strength < hiWk.strength, "STRENGTH strictly increases with workout energy")

    // RB #4 — STRENGTH bounded/finite under pathological workout (huge / negative / NaN).
    let extremeWk = DailyHealthInput.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: 1_000_000), hrvBaseline: baseline,
        at: s2Epoch)
    expect((0...100).contains(extremeWk.strength), "huge workout → STRENGTH <= 100")
    let negWk = DailyHealthInput.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: -100), hrvBaseline: baseline,
        at: s2Epoch)
    expect((0...100).contains(negWk.strength), "negative workout → STRENGTH >= 0")
    let infWk = DailyHealthInput.derive(
        from: HealthMetrics(activeWorkoutEnergyKilocalories: .infinity), hrvBaseline: baseline,
        at: s2Epoch)
    expect(
        infWk.strength.isFinite && (0...100).contains(infWk.strength),
        "infinite workout → STRENGTH finite in 0...100")
    let nanAll = DailyHealthInput.derive(
        from: HealthMetrics(
            restingHeartRate: .nan, hrvRMSSD: .nan, sleepEfficiency: .nan,
            activeWorkoutEnergyKilocalories: .nan), hrvBaseline: baseline, at: s2Epoch)
    for v in [nanAll.fatigue, nanAll.strength, nanAll.hunger] {
        expect(v.isFinite && (0...100).contains(v), "NaN metrics → daily input finite in 0...100")
    }

    // RB #13 — STRENGTH depends ONLY on workout energy: invariant to each non-workout input
    // varied INDIVIDUALLY, and to the HRV baseline.
    let sBase = DailyHealthInput.derive(from: fBaseM, hrvBaseline: baseline, at: s2Epoch).strength
    let sVaryHRV = DailyHealthInput.derive(
        from: HealthMetrics(
            restingHeartRate: 60, hrvRMSSD: 90, sleepEfficiency: 0.5,
            activeWorkoutEnergyKilocalories: 300), hrvBaseline: baseline, at: s2Epoch).strength
    let sVaryRHR = DailyHealthInput.derive(
        from: HealthMetrics(
            restingHeartRate: 40, hrvRMSSD: 55, sleepEfficiency: 0.5,
            activeWorkoutEnergyKilocalories: 300), hrvBaseline: baseline, at: s2Epoch).strength
    let sVarySleep = DailyHealthInput.derive(from: fVarySleep, hrvBaseline: baseline, at: s2Epoch)
        .strength
    let sNoBaseline = DailyHealthInput.derive(from: fBaseM, hrvBaseline: [], at: s2Epoch).strength
    expect(sVaryHRV == sBase, "STRENGTH invariant to HRV alone")
    expect(sVaryRHR == sBase, "STRENGTH invariant to RHR alone")
    expect(sVarySleep == sBase, "STRENGTH invariant to sleep alone")
    expect(sNoBaseline == sBase, "STRENGTH invariant to HRV baseline")

    // RB #10 — HUNGER neutral placeholder = 50.0, independent of metrics (incl. NaN) & baseline.
    expect(empty.hunger == 50.0, "HUNGER == 50.0 with no metrics")
    expect(nanAll.hunger == 50.0, "HUNGER == 50.0 under NaN metrics")
    expect(
        DailyHealthInput.derive(
            from: HealthMetrics(activeWorkoutEnergyKilocalories: 300), hrvBaseline: baseline,
            at: s2Epoch).hunger == 50.0, "HUNGER == 50.0 regardless of workout")
}

// RB #12 — async seam: source → latestMetrics() → DailyHealthInput.derive == direct derive.
await group("daily-input-source") {
    let m = HealthMetrics(
        restingHeartRate: 55, hrvRMSSD: 45, sleepEfficiency: 0.9,
        activeWorkoutEnergyKilocalories: 300)
    let baseline = (0..<28).map { 40.0 + Double($0) }
    let source = FakeHealthDataSource(stored: m)
    let fetched = await source.latestMetrics()
    let viaSource = DailyHealthInput.derive(from: fetched, hrvBaseline: baseline, at: s2Epoch)
    let direct = DailyHealthInput.derive(from: m, hrvBaseline: baseline, at: s2Epoch)
    expect(viaSource.capturedAt == direct.capturedAt, "source round-trip capturedAt matches")
    expect(viaSource.fatigue == direct.fatigue, "source round-trip FATIGUE matches direct derive")
    expect(
        viaSource.strength == direct.strength, "source round-trip STRENGTH matches direct derive")
    expect(viaSource.hunger == direct.hunger, "source round-trip HUNGER matches direct derive")
}

// MARK: - Stage 1 · Slice 6b — EWMA accumulation primitive (RED)
//
// Time-aware exponential accumulation for HEALTH sub-stats (ADR-002 Decision 2):
// retentionᐞ = 0.5^(Δt / halfLife); result = retentionᐞ·previous + (1−retentionᐞ)·input.
// Pure core; cold start is the store's job (seeds accumulated = dailyInput).

group("health-ewma") {
    let hl = 4.0
    // Δt = 0 → retention 1 → unchanged (no new info without elapsed time).
    expect(
        EWMA.accumulate(previous: 80, dailyInput: 20, elapsedDays: 0, halfLifeDays: hl) == 80,
        "EWMA Δt=0 → value unchanged")
    // One half-life → retention 0.5 → exact midpoint.
    expect(
        EWMA.accumulate(previous: 80, dailyInput: 20, elapsedDays: hl, halfLifeDays: hl) == 50,
        "EWMA one half-life → midpoint (80,20) → 50")
    // Monotone toward input: larger dailyInput → larger result (previous, Δt fixed).
    let loIn = EWMA.accumulate(previous: 50, dailyInput: 10, elapsedDays: 2, halfLifeDays: hl)
    let hiIn = EWMA.accumulate(previous: 50, dailyInput: 90, elapsedDays: 2, halfLifeDays: hl)
    expect(loIn < hiIn, "EWMA monotone increasing in dailyInput")
    // Convex-combination bounds → within [dailyInput, previous], hence finite & in 0...100.
    let blended = EWMA.accumulate(previous: 80, dailyInput: 20, elapsedDays: 3, halfLifeDays: hl)
    expect((20...80).contains(blended), "EWMA result within [dailyInput, previous]")
    // Multi-day gap decays MORE than one step (toward input 0): bigger Δt ⇒ closer to input.
    let step1 = EWMA.accumulate(previous: 80, dailyInput: 0, elapsedDays: 1, halfLifeDays: hl)
    let step5 = EWMA.accumulate(previous: 80, dailyInput: 0, elapsedDays: 5, halfLifeDays: hl)
    expect(step5 < step1, "EWMA: larger gap decays more (closer to input)")
    // Negative Δt clamps to 0 → unchanged.
    expect(
        EWMA.accumulate(previous: 80, dailyInput: 20, elapsedDays: -3, halfLifeDays: hl) == 80,
        "EWMA negative Δt clamped to 0 → unchanged")
    // Finite under pathological Δt (infinite elapsed → fully decays to input).
    let infDt = EWMA.accumulate(
        previous: 80, dailyInput: 20, elapsedDays: .infinity, halfLifeDays: hl)
    expect(infDt.isFinite && (0...100).contains(infDt), "EWMA finite under infinite Δt")
}

// MARK: - Stage 1 · Slice 6b — baseline-relative HRV recovery reading (RED)
//
// The Recovery HRV term, extracted + reused as the FATIGUE daily input (ADR-002
// Decision 3). Neutral 50 while calibrating (<14 finite baseline, nil/non-finite
// today-HRV, or std < 1 ms). Must equal the HRV term embedded in Recovery.score.

group("health-hrv-recovery-reading") {
    let baselineVaried = (0..<28).map { 40.0 + Double($0) }  // mean 53.5, std > 1
    let baselineFew = Array(repeating: 50.0, count: 10)
    let baselineZeroVar = Array(repeating: 50.0, count: 28)

    // Calibrating → neutral 50.
    expect(
        Recovery.hrvRecoveryReading(todayHRV: 55, baseline: baselineFew) == 50,
        "<14 finite baseline → 50 (calibrating)")
    expect(
        Recovery.hrvRecoveryReading(todayHRV: nil, baseline: baselineVaried) == 50,
        "nil today-HRV → 50")
    expect(
        Recovery.hrvRecoveryReading(todayHRV: .nan, baseline: baselineVaried) == 50,
        "NaN today-HRV → 50")
    expect(
        Recovery.hrvRecoveryReading(todayHRV: 60, baseline: baselineZeroVar) == 50,
        "std < 1 baseline → 50 (neutral)")

    // Scored: strictly increases with today-HRV; above/below mean ⇒ >/< 50; clamped 0...100.
    let below = Recovery.hrvRecoveryReading(todayHRV: 42, baseline: baselineVaried)
    let above = Recovery.hrvRecoveryReading(todayHRV: 66, baseline: baselineVaried)
    expect(below < above, "reading strictly increases with today-HRV")
    expect(below < 50 && above > 50, "below/above baseline mean reads </> 50")
    expect((0...100).contains(below) && (0...100).contains(above), "reading clamped 0...100")

    // Clamp rails: an extreme today-HRV would blow the z-score past 0...100 without the clamp.
    expect(
        Recovery.hrvRecoveryReading(todayHRV: 1000, baseline: baselineVaried) == 100,
        "today-HRV far above baseline clamps to 100")
    expect(
        Recovery.hrvRecoveryReading(todayHRV: -500, baseline: baselineVaried) == 0,
        "today-HRV far below baseline clamps to 0")
    // Non-finite baseline entries are EXCLUDED (>=14 finite remain) → finite, same as clean.
    let dirtyBaseline = baselineVaried + [.nan, .infinity, -.infinity]
    expect(
        Recovery.hrvRecoveryReading(todayHRV: 66, baseline: dirtyBaseline) == above,
        "non-finite baseline entries excluded → same reading as the clean baseline")

    // Consistency — equals the HRV term embedded in Recovery.score. With RHR & sleep absent both
    // default to 50, so score = 0.5·hrvTerm + 0.25·50 + 0.25·50 ⇒ hrvTerm = (value − 25) / 0.5.
    let scored = Recovery.score(
        for: recoverySnap(HealthMetrics(hrvRMSSD: 66)), hrvBaseline: baselineVaried)
    if case .scored(let value, _) = scored {
        expect(
            abs((value - 25.0) / 0.5 - above) < 1e-9,
            "hrvRecoveryReading == the HRV term inside Recovery.score")
    } else {
        expect(false, "expected .scored for full baseline + finite HRV")
    }
}

// MARK: - Stage 1 · Slice 3 — Recovery score (RED)
//
// Recovery 0–100 + RED/YELLOW/GREEN bands from a HealthSnapshot's raw HRV / RHR /
// sleep, baseline-normalized vs a 28-day HRV window. Property-based + anti-cheat
// (strict per-input contribution, band reachability, no-double-count). S3 CONTRACT.

private func recoverySnap(_ metrics: HealthMetrics) -> HealthSnapshot {
    HealthSnapshot(capturedAt: s2Epoch, metrics: metrics)
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

    // RB #11 — no double-count: vary workout energy (carried in metrics);
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

// MARK: - Stage 1 · Slice 4 — Strain score (RED)
//
// Strain 0–21 (Whoop-convention) from a HealthSnapshot's raw active workout
// energy — the one metric Recovery (S3) does NOT read. Property-based (NOT
// pinned to the Stage-1 curve constant K) so the curve can be retuned without
// breaking these tests. S4 CONTRACT.

private func strainSnap(_ metrics: HealthMetrics) -> HealthSnapshot {
    HealthSnapshot(capturedAt: s2Epoch, metrics: metrics)
}

@MainActor
private func strainValue(_ result: StrainResult) -> Double {
    if case .scored(let value) = result { return value }
    expect(false, "expected .scored, got .noData (finite active energy must score)")
    return -1
}

group("strain-score") {
    // SB#1 — StrainResult is Equatable.
    expect(StrainResult.noData == .noData, "StrainResult.noData Equatable")
    expect(StrainResult.scored(value: 1) != .noData, "scored != noData")
    expect(StrainResult.scored(value: 5) == .scored(value: 5), "scored value Equatable")

    // SB#2 — nil active energy → .noData (omitted ≠ a measured 0).
    expect(
        Strain.score(for: strainSnap(HealthMetrics())) == .noData,
        "nil active energy → .noData")
    expect(
        Strain.score(for: strainSnap(HealthMetrics(hrvRMSSD: 50, sleepEfficiency: 0.9)))
            == .noData,
        "nil active energy (other metrics present) → .noData")

    // SB#3 — non-finite active energy → .noData (NaN / +inf / -inf).
    expect(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: .nan)))
            == .noData,
        "NaN active energy → .noData")
    expect(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: .infinity)))
            == .noData,
        "+inf active energy → .noData")
    expect(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: -.infinity)))
            == .noData,
        "-inf active energy → .noData")

    // SB#4 — finite active energy → .scored, value finite & in 0...21.
    let s300 = Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 300)))
    if case .scored(let v) = s300 {
        expect(v.isFinite && (0...21).contains(v), "scored value finite & in 0...21")
    } else {
        expect(false, "expected .scored for finite active energy")
    }

    // SB#5 — 0 kcal → .scored(value: 0) (rest day = zero-Strain anchor).
    expect(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 0)))
            == .scored(value: 0),
        "0 kcal → Strain 0 (rest day)")

    // SB#6 — strict monotonicity in active energy.
    let m150 = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 150))))
    let m600 = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 600))))
    let m1500 = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 1500))))
    expect(m150 < m600 && m600 < m1500, "Strain strictly increases with active energy")

    // SB#7 — diminishing returns / concavity (committed Stage-1 behavior): equal energy
    // increments add strictly less Strain at higher energy (forbids a linear map).
    let s0 = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 0))))
    let s600 = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 600))))
    let s1200 = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 1200))))
    expect((s1200 - s600) < (s600 - s0), "diminishing returns: concave, not linear")

    // SB#8 — large input saturates: finite, ≤ 21, still monotone at the top.
    let sHuge = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 100_000))))
    expect(sHuge.isFinite && sHuge <= 21, "huge active energy → finite, ≤ 21 (saturates)")
    expect(sHuge > s600, "huge active energy still monotone above 600 kcal")

    // SB#9 — negative FINITE kcal → .scored equal to the zero anchor (clamp to 0 exertion;
    // NOT .noData — non-finite is SB#3's path).
    expect(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: -100)))
            == Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 0))),
        "negative finite kcal clamps to 0 → strain(-100) == strain(0)")
    let sNeg = strainValue(
        Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: -100))))
    expect(sNeg.isFinite && (0...21).contains(sNeg), "negative kcal → finite, in 0...21")

    // SB#10 — across an ascending sweep: every value finite & in 0...21 AND strictly
    // increasing (monotonicity holds everywhere, not only at SB#6's three points).
    var prevStrain = -1.0
    for kcal in [0.0, 1, 50, 200, 450, 800, 1600, 5000, 50_000] {
        let v = strainValue(
            Strain.score(for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: kcal))))
        expect(v.isFinite && (0...21).contains(v), "sweep kcal=\(kcal) → value in 0...21")
        expect(v > prevStrain, "sweep strictly increasing at kcal=\(kcal)")
        prevStrain = v
    }

    // SB#11 — reads ONLY workout energy: with active energy fixed at 300, varying RHR / HRV /
    // sleep individually does not change Strain (analogous to S2 RB#13 STRENGTH-only).
    let strainBase = Strain.score(
        for: strainSnap(
            HealthMetrics(
                restingHeartRate: 60, hrvRMSSD: 20, sleepEfficiency: 0.5,
                activeWorkoutEnergyKilocalories: 300)))
    let strainVaryRHR = Strain.score(
        for: strainSnap(
            HealthMetrics(
                restingHeartRate: 40, hrvRMSSD: 20, sleepEfficiency: 0.5,
                activeWorkoutEnergyKilocalories: 300)))
    let strainVaryHRV = Strain.score(
        for: strainSnap(
            HealthMetrics(
                restingHeartRate: 60, hrvRMSSD: 90, sleepEfficiency: 0.5,
                activeWorkoutEnergyKilocalories: 300)))
    let strainVarySleep = Strain.score(
        for: strainSnap(
            HealthMetrics(
                restingHeartRate: 60, hrvRMSSD: 20, sleepEfficiency: 0.95,
                activeWorkoutEnergyKilocalories: 300)))
    expect(strainBase == strainVaryRHR, "Strain invariant to RHR (active energy fixed)")
    expect(strainBase == strainVaryHRV, "Strain invariant to HRV (active energy fixed)")
    expect(strainBase == strainVarySleep, "Strain invariant to sleep (active energy fixed)")
    // SB#11b (Codex tests-review IMPORTANT #2) — invariant to PRESENCE of the non-energy
    // fields too: an energy-only snapshot scores the same as a fully-populated one (forbids
    // a presence-based side term that still reads the forbidden fields).
    let strainEnergyOnly = Strain.score(
        for: strainSnap(HealthMetrics(activeWorkoutEnergyKilocalories: 300)))
    expect(
        strainBase == strainEnergyOnly,
        "Strain invariant to presence of RHR/HRV/sleep (energy-only == fully-populated)")
}

// MARK: - Summary
//
// Fail-fast above means reaching here implies every expectation passed.
print("✅ \(Runner.passCount) passed, 0 failed")

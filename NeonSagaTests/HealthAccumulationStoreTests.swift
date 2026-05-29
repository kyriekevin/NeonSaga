import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S6b RED tests (ADR-002): HEALTH sub-stat ACCUMULATION + write-path idempotence.
// `deriveAndStore` must:
//   (a) accumulate today's `DailyHealthInput` onto the carried-forward stored value
//       with a TIME-AWARE EWMA (retention^Δt over elapsed days);
//   (b) upsert ONE record per local-calendar stat-day — the label `(y,m,d)` in the
//       record's CAPTURE ZONE, never a UTC instant;
//   (c) re-derive the affected suffix on out-of-order / back-filled inputs.
// Fails until the green commit replaces the naive-insert stub in the store.
final class HealthAccumulationStoreTests: XCTestCase {

    private struct StubSource: HealthDataSource {
        let metrics: HealthMetrics
        func latestMetrics() async throws -> HealthMetrics { metrics }
    }

    private let utc = TimeZone(identifier: "UTC")!
    private let sgt = TimeZone(identifier: "Asia/Singapore")!      // UTC+8, no DST
    private let la = TimeZone(identifier: "America/Los_Angeles")!  // UTC-7/-8, observes DST

    private func cal(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    /// Deterministic instant for a local `(y,m,d,h)` in `zone` — no `Date.now` / host TZ.
    private func date(_ zone: TimeZone, _ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal(zone).date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
    }

    @MainActor
    private func makeStore(_ zone: TimeZone) throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container), calendar: cal(zone))
    }

    @discardableResult
    @MainActor
    private func write(
        _ store: HealthSnapshotStore, _ metrics: HealthMetrics, at when: Date, in zone: TimeZone
    ) async throws -> HealthSnapshotRecord {
        try await store.deriveAndStore(from: StubSource(metrics: metrics), at: when, capturedIn: zone)
    }

    // MARK: - Accumulation values (load-bearing once EWMA + DailyHealthInput land)

    @MainActor
    func testColdStartAccumulatedEqualsDailyInput() async throws {
        let store = try makeStore(utc)
        let m = HealthMetrics(hrvRMSSD: 60, activeWorkoutEnergyKilocalories: 600)
        let day0 = date(utc, 2026, 6, 1)
        let rec = try await write(store, m, at: day0, in: utc)
        let expected = DailyHealthInput.derive(from: m, hrvBaseline: [], at: day0)
        XCTAssertEqual(rec.strengthValue, expected.strength, accuracy: 1e-9)
        XCTAssertEqual(rec.fatigueValue, expected.fatigue, accuracy: 1e-9)
        XCTAssertEqual(rec.hungerValue, expected.hunger, accuracy: 1e-9)
    }

    @MainActor
    func testSecondDayAccumulatesViaTimeAwareEWMA() async throws {
        let store = try makeStore(utc)
        let day1 = date(utc, 2026, 6, 1)
        let day2 = date(utc, 2026, 6, 2)
        // Day 1 big workout, day 2 rest (0 kcal) — a DIFFERENT strength daily input, so
        // EWMA accumulation differs from naively storing day-2's input.
        let r1 = try await write(
            store, HealthMetrics(activeWorkoutEnergyKilocalories: 600), at: day1, in: utc)
        let r2 = try await write(
            store, HealthMetrics(activeWorkoutEnergyKilocalories: 0), at: day2, in: utc)
        let day2Input = DailyHealthInput.derive(
            from: HealthMetrics(activeWorkoutEnergyKilocalories: 0), hrvBaseline: [], at: day2)
        let expected = EWMA.accumulate(
            previous: r1.strengthValue, dailyInput: day2Input.strength,
            elapsedDays: 1, halfLifeDays: HealthAccumulation.strengthHalfLifeDays)
        XCTAssertEqual(r2.strengthValue, expected, accuracy: 1e-9)
    }

    @MainActor
    func testStrengthDecaysOnRestButStaysPositive() async throws {
        let store = try makeStore(utc)
        let r1 = try await write(
            store, HealthMetrics(activeWorkoutEnergyKilocalories: 600), at: date(utc, 2026, 6, 1),
            in: utc)
        var prev = r1.strengthValue
        for d in 2...5 {
            let r = try await write(
                store, HealthMetrics(activeWorkoutEnergyKilocalories: 0), at: date(utc, 2026, 6, d),
                in: utc)
            XCTAssertLessThan(r.strengthValue, prev, "STRENGTH strictly decays on a rest day")
            XCTAssertGreaterThan(r.strengthValue, 0, "STRENGTH does not crater to 0 in one rest day")
            prev = r.strengthValue
        }
    }

    @MainActor
    func testMultiDayGapDecaysMoreThanOneStep() async throws {
        let near = try makeStore(utc)
        let far = try makeStore(utc)
        let m1 = HealthMetrics(activeWorkoutEnergyKilocalories: 600)
        let rest = HealthMetrics(activeWorkoutEnergyKilocalories: 0)
        _ = try await write(near, m1, at: date(utc, 2026, 6, 1), in: utc)
        let near2 = try await write(near, rest, at: date(utc, 2026, 6, 2), in: utc)  // 1-day gap
        _ = try await write(far, m1, at: date(utc, 2026, 6, 1), in: utc)
        let far2 = try await write(far, rest, at: date(utc, 2026, 6, 10), in: utc)  // 9-day gap
        XCTAssertLessThan(
            far2.strengthValue, near2.strengthValue,
            "a longer gap decays STRENGTH more (closer to the rest-day input)")
    }

    // MARK: - FATIGUE at the store: HRV-only, baseline-relative, accumulated

    @MainActor
    func testFatigueIgnoresSleepAndWorkoutAtStore() async throws {
        // Two stores with an identical >=14-day HRV baseline; the test day differs ONLY in
        // sleep + workout (same poor HRV). FATIGUE must be identical — ADR-002 Decision 1:
        // neither sleep nor workout feeds FATIGUE.
        func fatigueOnTestDay(_ testDay: HealthMetrics) async throws -> Double {
            let store = try makeStore(utc)
            for i in 1...14 {
                let hrv: Double = (i % 2 == 0) ? 60 : 40  // mean 50, std > 1
                _ = try await write(store, HealthMetrics(hrvRMSSD: hrv), at: date(utc, 2026, 6, i), in: utc)
            }
            return try await write(store, testDay, at: date(utc, 2026, 6, 15), in: utc).fatigueValue
        }
        let lowLoad = try await fatigueOnTestDay(
            HealthMetrics(hrvRMSSD: 30, sleepEfficiency: 0.2, activeWorkoutEnergyKilocalories: 0))
        let highLoad = try await fatigueOnTestDay(
            HealthMetrics(hrvRMSSD: 30, sleepEfficiency: 0.95, activeWorkoutEnergyKilocalories: 600))
        XCTAssertEqual(lowLoad, highLoad, accuracy: 1e-9, "FATIGUE ignores sleep + workout at the store")
        XCTAssertLessThan(lowLoad, 50, "poor HRV (below baseline mean) → FATIGUE below neutral 50")
    }

    @MainActor
    func testFatigueAccumulatesViaTimeAwareEWMAFromBaselineRelativeReading() async throws {
        let store = try makeStore(utc)
        for i in 1...14 {
            let hrv: Double = (i % 2 == 0) ? 60 : 40
            _ = try await write(store, HealthMetrics(hrvRMSSD: hrv), at: date(utc, 2026, 6, i), in: utc)
        }
        let r15 = try await write(store, HealthMetrics(hrvRMSSD: 35), at: date(utc, 2026, 6, 15), in: utc)
        let r16 = try await write(store, HealthMetrics(hrvRMSSD: 35), at: date(utc, 2026, 6, 16), in: utc)
        // Day-16 FATIGUE = one time-aware EWMA step from day-15's accumulated value toward
        // day-16's baseline-relative HRV reading (using the store's own baseline + primitives).
        let baseline16 = try store.recentHRVBaseline(before: date(utc, 2026, 6, 16))
        let input16 = Recovery.hrvRecoveryReading(todayHRV: 35, baseline: baseline16)
        let expected = EWMA.accumulate(
            previous: r15.fatigueValue, dailyInput: input16,
            elapsedDays: 1, halfLifeDays: HealthAccumulation.fatigueHalfLifeDays)
        XCTAssertEqual(r16.fatigueValue, expected, accuracy: 1e-9)
    }

    // MARK: - Write-path idempotence: upsert ONE record per local-calendar stat-day

    @MainActor
    func testSameStatDayUpsertsRetainingLatestWithoutDoubleAccumulating() async throws {
        let store = try makeStore(utc)
        // A prior stat-day gives a non-trivial accumulated STRENGTH to step from.
        let day1 = try await write(
            store, HealthMetrics(activeWorkoutEnergyKilocalories: 600), at: date(utc, 2026, 6, 1),
            in: utc)
        // Two writes on 2026-06-02 (09:00 then 21:00) collapse to ONE record that retains the
        // LATEST raw metrics and accumulates a SINGLE step from day 1 (no double-count).
        _ = try await write(
            store, HealthMetrics(activeWorkoutEnergyKilocalories: 0), at: date(utc, 2026, 6, 2, 9),
            in: utc)
        let evening = try await write(
            store, HealthMetrics(activeWorkoutEnergyKilocalories: 300), at: date(utc, 2026, 6, 2, 21),
            in: utc)

        let all = try store.allRecords()
        XCTAssertEqual(all.count, 2, "day 1 + the single upserted day-2 record")
        XCTAssertEqual(
            evening.activeWorkoutEnergyKilocalories, 300, "latest same-day raw metrics retained")
        let elapsed = evening.capturedAt.timeIntervalSince(day1.capturedAt) / 86_400.0
        let expected = EWMA.accumulate(
            previous: day1.strengthValue,
            dailyInput: DailyHealthInput.derive(
                from: HealthMetrics(activeWorkoutEnergyKilocalories: 300), hrvBaseline: [],
                at: evening.capturedAt).strength,
            elapsedDays: elapsed, halfLifeDays: HealthAccumulation.strengthHalfLifeDays)
        XCTAssertEqual(
            evening.strengthValue, expected, accuracy: 1e-9,
            "single EWMA step from day 1 to the latest same-day input, not doubled")
    }

    @MainActor
    func testExactDuplicateCapturedAtUpsertsRetainingLatest() async throws {
        let store = try makeStore(utc)
        let t = date(utc, 2026, 6, 1, 12)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 50), at: t, in: utc)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 60), at: t, in: utc)
        XCTAssertEqual(try store.allRecords().count, 1, "identical capturedAt → one record")
        XCTAssertEqual(try store.latest()?.hrvRMSSD, 60, "latest write's raw metrics retained")
    }

    @MainActor
    func testDistinctStatDaysStaySeparate() async throws {
        let store = try makeStore(utc)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 50), at: date(utc, 2026, 6, 1), in: utc)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 60), at: date(utc, 2026, 6, 2), in: utc)
        XCTAssertEqual(try store.allRecords().count, 2, "two distinct stat-days → two records")
    }

    // MARK: - Stat-day key is the local DATE LABEL in the capture zone, not a UTC instant

    @MainActor
    func testCrossZoneSameLocalDateLabelCollapsesToOneRecord() async throws {
        let store = try makeStore(utc)
        // 2026-06-01 10:00 in SGT and 2026-06-01 10:00 in LA — same (y,m,d) LABEL in each
        // zone, different absolute instants. ADR-002: same label ⇒ ONE record.
        _ = try await write(store, HealthMetrics(hrvRMSSD: 50), at: date(sgt, 2026, 6, 1, 10), in: sgt)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 60), at: date(la, 2026, 6, 1, 10), in: la)
        XCTAssertEqual(
            try store.allRecords().count, 1, "same (y,m,d) label across capture zones → one record")
    }

    @MainActor
    func testSameInstantDifferentLocalDateLabelsStaySeparate() async throws {
        let store = try makeStore(utc)
        // 2026-06-01 23:00Z is 2026-06-02 in SGT (+8) but 2026-06-01 in LA (-7) — same
        // absolute instant, different local-date labels ⇒ TWO records (key is the label).
        let instant = date(utc, 2026, 6, 1, 23)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 50), at: instant, in: sgt)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 60), at: instant, in: la)
        XCTAssertEqual(
            try store.allRecords().count, 2,
            "same instant, different local-date labels → two records")
    }

    @MainActor
    func testDSTBoundarySameLocalDateLabelCollapses() async throws {
        let store = try makeStore(utc)
        // 2026-03-08 is US spring-forward (02:00→03:00 PDT). Two LA writes straddling the
        // skipped hour share the (y,m,d) label 03-08 → ONE record. 01:00 (PST) and 23:00
        // (PDT) are both real local times (avoids the nonexistent 02:00–02:59 gap).
        _ = try await write(store, HealthMetrics(hrvRMSSD: 50), at: date(la, 2026, 3, 8, 1), in: la)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 60), at: date(la, 2026, 3, 8, 23), in: la)
        XCTAssertEqual(
            try store.allRecords().count, 1, "same LA local date across the DST jump → one record")
    }

    @MainActor
    func testDSTBoundaryDifferentLocalDateLabelsStaySeparate() async throws {
        let store = try makeStore(utc)
        // Straddle the same 2026-03-08 spring-forward but on DIFFERENT local dates:
        // 2026-03-07 23:00 (PST, label 03-07) and 2026-03-08 03:00 (PDT, label 03-08;
        // 03:00 is the first valid time after the 02:00→03:00 jump) → TWO records.
        _ = try await write(store, HealthMetrics(hrvRMSSD: 50), at: date(la, 2026, 3, 7, 23), in: la)
        _ = try await write(store, HealthMetrics(hrvRMSSD: 60), at: date(la, 2026, 3, 8, 3), in: la)
        XCTAssertEqual(
            try store.allRecords().count, 2,
            "different LA local dates across the DST jump → two records")
    }

    // MARK: - Back-fill re-derives the affected suffix

    @MainActor
    func testBackfillReDerivesSuffix() async throws {
        let store = try makeStore(utc)
        let day1 = date(utc, 2026, 6, 1)
        let day2 = date(utc, 2026, 6, 2)
        let day3 = date(utc, 2026, 6, 3)
        let m1 = HealthMetrics(activeWorkoutEnergyKilocalories: 600)
        let m2 = HealthMetrics(activeWorkoutEnergyKilocalories: 300)
        let m3 = HealthMetrics(activeWorkoutEnergyKilocalories: 0)
        // Write day 1 and day 3, THEN back-fill day 2.
        _ = try await write(store, m1, at: day1, in: utc)
        _ = try await write(store, m3, at: day3, in: utc)
        _ = try await write(store, m2, at: day2, in: utc)

        // Day-3 accumulated STRENGTH must equal a clean forward chain day1→day2→day3.
        let hl = HealthAccumulation.strengthHalfLifeDays
        let s1 = DailyHealthInput.derive(from: m1, hrvBaseline: [], at: day1).strength  // cold start
        let s2 = EWMA.accumulate(
            previous: s1,
            dailyInput: DailyHealthInput.derive(from: m2, hrvBaseline: [], at: day2).strength,
            elapsedDays: 1, halfLifeDays: hl)
        let s3 = EWMA.accumulate(
            previous: s2,
            dailyInput: DailyHealthInput.derive(from: m3, hrvBaseline: [], at: day3).strength,
            elapsedDays: 1, halfLifeDays: hl)

        let records = try store.allRecords()
        XCTAssertEqual(records.count, 3, "three distinct stat-days → three records")
        let day3Record = try XCTUnwrap(records.last)
        XCTAssertEqual(day3Record.capturedAt, day3)
        XCTAssertEqual(
            day3Record.strengthValue, s3, accuracy: 1e-9, "day-3 re-derived after back-fill")
    }
}

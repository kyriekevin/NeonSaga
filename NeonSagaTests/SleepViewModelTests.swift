import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

/// S8 RED — Sleep architecture in `HealthDetailViewModel` + the persistence seam.
/// The VM exposes `sleep: SleepResult`, derived by `Sleep.summary` from the latest
/// record's raw sleep-stage signals. The five raw sleep fields persist losslessly
/// through `HealthSnapshotRecord` (init + adapter) AND through the `deriveAndStore`
/// same-stat-day overwrite branch; an empty HEALTH state shows no stale sleep.
/// Presentation (the SleepCard layout) is not unit-tested here (ADR-003 Layer-0).
final class SleepViewModelTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private let utc = TimeZone(identifier: "UTC")!

    private struct StubSource: HealthDataSource {
        let metrics: HealthMetrics
        func latestMetrics() async throws -> HealthMetrics { metrics }
    }

    private func cal(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    @MainActor
    private func makeStore() throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container))
    }

    /// Seeds one record whose raw metrics carry sleep stages (accumulated sub-stat
    /// values are neutral — Sleep does not read them).
    @MainActor
    private func seed(
        _ store: HealthSnapshotStore, _ metrics: HealthMetrics, at when: Date
    ) throws {
        try store.save(
            HealthSnapshotRecord(
                capturedAt: when, metrics: metrics, hunger: 0, fatigue: 0, strength: 0))
    }

    // MARK: - VM exposes Sleep (required behavior 3 / 4)

    @MainActor
    func testNoDataYieldsNoSleep() throws {
        let vm = HealthDetailViewModel(store: try makeStore())
        XCTAssertEqual(vm.sleep, .noData)
    }

    @MainActor
    func testRecordWithStagesYieldsScoredSummary() throws {
        let store = try makeStore()
        try seed(
            store,
            HealthMetrics(deepSleepMinutes: 90, remSleepMinutes: 60, lightSleepMinutes: 240),
            at: base)
        let vm = HealthDetailViewModel(store: store)

        guard case .scored(let s) = vm.sleep else {
            return XCTFail("expected .scored, got \(vm.sleep)")
        }
        XCTAssertEqual(s.deepMinutes, 90, accuracy: 1e-9)
        XCTAssertEqual(s.remMinutes, 60, accuracy: 1e-9)
        XCTAssertEqual(s.lightMinutes, 240, accuracy: 1e-9)
        XCTAssertEqual(s.asleepMinutes, 390, accuracy: 1e-9)
    }

    // MARK: - Round-trip through persistence (record init + adapter copy sites)

    @MainActor
    func testSleepFieldsRoundTripThroughPersistence() throws {
        let store = try makeStore()
        try seed(
            store,
            HealthMetrics(
                deepSleepMinutes: 80, remSleepMinutes: 70, lightSleepMinutes: 250,
                timeInBedMinutes: 430, wakeEventsCount: 4),
            at: base)
        let vm = HealthDetailViewModel(store: store)

        guard case .scored(let s) = vm.sleep else {
            return XCTFail("expected .scored, got \(vm.sleep)")
        }
        XCTAssertEqual(s.deepMinutes, 80, accuracy: 1e-9)
        XCTAssertEqual(s.remMinutes, 70, accuracy: 1e-9)
        XCTAssertEqual(s.lightMinutes, 250, accuracy: 1e-9)
        XCTAssertEqual(s.timeInBedMinutes ?? -1, 430, accuracy: 1e-9)
        XCTAssertEqual(s.wakeEvents, 4)
    }

    // MARK: - deriveAndStore persists sleep across insert + same-stat-day overwrite

    @MainActor
    func testDeriveAndStorePersistsSleepFields() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        let store = HealthSnapshotStore(context: ModelContext(container), calendar: cal(utc))
        let day = cal(utc).date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!

        // Insert: sleep A (all five sleep fields distinct from B).
        _ = try await store.deriveAndStore(
            from: StubSource(
                metrics: HealthMetrics(
                    deepSleepMinutes: 60, remSleepMinutes: 50, lightSleepMinutes: 200,
                    timeInBedMinutes: 340, wakeEventsCount: 2)),
            at: day, capturedIn: utc)
        let afterInsert = try XCTUnwrap(try store.latest())
        XCTAssertEqual(afterInsert.deepSleepMinutes ?? -1, 60, accuracy: 1e-9)
        XCTAssertEqual(afterInsert.timeInBedMinutes ?? -1, 340, accuracy: 1e-9)
        XCTAssertEqual(afterInsert.wakeEventsCount, 2)

        // Same stat-day overwrite: sleep B (every field different) — must replace, not
        // retain A. Asserting timeInBed + wakeEvents too guards the overwrite branch
        // against copying only the stage minutes (Codex tests-review finding 1).
        _ = try await store.deriveAndStore(
            from: StubSource(
                metrics: HealthMetrics(
                    deepSleepMinutes: 95, remSleepMinutes: 65, lightSleepMinutes: 230,
                    timeInBedMinutes: 410, wakeEventsCount: 5)),
            at: day, capturedIn: utc)
        XCTAssertEqual(try store.allRecords().count, 1, "same stat-day upserts a single record")
        let after = try XCTUnwrap(try store.latest())
        XCTAssertEqual(after.deepSleepMinutes ?? -1, 95, accuracy: 1e-9)
        XCTAssertEqual(after.remSleepMinutes ?? -1, 65, accuracy: 1e-9)
        XCTAssertEqual(after.lightSleepMinutes ?? -1, 230, accuracy: 1e-9)
        XCTAssertEqual(after.timeInBedMinutes ?? -1, 410, accuracy: 1e-9)
        XCTAssertEqual(after.wakeEventsCount, 5)
    }

    // MARK: - No stale sleep over an empty HEALTH state (coherence)

    @MainActor
    func testNoDataAfterDataClearsSleep() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = HealthSnapshotStore(context: context)

        let record = HealthSnapshotRecord(
            capturedAt: base,
            metrics: HealthMetrics(
                deepSleepMinutes: 90, remSleepMinutes: 60, lightSleepMinutes: 240),
            hunger: 0, fatigue: 0, strength: 0)
        context.insert(record)
        try context.save()

        let vm = HealthDetailViewModel(store: store)
        guard case .scored = vm.sleep else {
            return XCTFail("expected .scored before deletion, got \(vm.sleep)")
        }

        context.delete(record)
        try context.save()
        vm.refresh()
        XCTAssertEqual(vm.sleep, .noData)
    }
}

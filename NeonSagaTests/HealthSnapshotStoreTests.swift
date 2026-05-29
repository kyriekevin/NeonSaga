import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S5 persistence tests, migrated for S6b (ADR-002): `HealthSnapshot` is now a metrics
// carrier, records carry ACCUMULATED sub-stat values, and records are built via
// `HealthSnapshotRecord(capturedAt:metrics:hunger:fatigue:strength:)`. Pins the @Model
// + store persistence seam (latest / save / cold-start deriveAndStore / error path).
// Accumulation behavior proper lives in `HealthAccumulationStoreTests`.
final class HealthSnapshotStoreTests: XCTestCase {

    // MARK: - Test doubles

    private struct StubSource: HealthDataSource {
        let metrics: HealthMetrics
        func latestMetrics() async throws -> HealthMetrics { metrics }
    }

    private struct SourceError: Error {}

    private struct ThrowingSource: HealthDataSource {
        func latestMetrics() async throws -> HealthMetrics { throw SourceError() }
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
    }

    /// Seeds one record (raw metrics + given ACCUMULATED values) at `capturedAt`.
    @MainActor
    private func seed(
        _ store: HealthSnapshotStore, _ metrics: HealthMetrics, at capturedAt: Date,
        hunger: Double = 50, fatigue: Double = 50, strength: Double = 0
    ) throws {
        try store.save(
            HealthSnapshotRecord(
                capturedAt: capturedAt, metrics: metrics,
                hunger: hunger, fatigue: fatigue, strength: strength))
    }

    // MARK: - latest() / save() (behaviors 1–6)

    @MainActor
    func testLatestOnEmptyStoreIsNil() throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        XCTAssertNil(try store.latest())
    }

    @MainActor
    func testSaveThenLatestRoundTripsValues() throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let metrics = HealthMetrics(
            restingHeartRate: 58, hrvRMSSD: 42, sleepEfficiency: 0.9,
            activeWorkoutEnergyKilocalories: 600)
        try seed(store, metrics, at: capturedAt, hunger: 40, fatigue: 70, strength: 88)

        let rec = try XCTUnwrap(try store.latest())
        XCTAssertEqual(rec.capturedAt, capturedAt)
        XCTAssertEqual(rec.restingHeartRate, 58)
        XCTAssertEqual(rec.hrvRMSSD, 42)
        XCTAssertEqual(rec.sleepEfficiency, 0.9)
        XCTAssertEqual(rec.activeWorkoutEnergyKilocalories, 600)
        XCTAssertEqual(rec.hungerValue, 40)
        XCTAssertEqual(rec.fatigueValue, 70)
        XCTAssertEqual(rec.strengthValue, 88)
    }

    @MainActor
    func testLatestReturnsMostRecentByCapturedAt() throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 2000)
        let t2 = Date(timeIntervalSince1970: 3000)
        // Insert out of chronological order: t1, t2, t0.
        for t in [t1, t2, t0] {
            try seed(store, HealthMetrics(), at: t)
        }
        XCTAssertEqual(try store.latest()?.capturedAt, t2)
    }

    @MainActor
    func testLatestTieBreaksByStoredAt() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = HealthSnapshotStore(context: context)
        let capturedAt = Date(timeIntervalSince1970: 5000)
        let earlier = Date(timeIntervalSince1970: 9000)
        let later = Date(timeIntervalSince1970: 9999)
        // Identical capturedAt on both isolates the storedAt tie-break (cannot pass
        // via a capturedAt difference).
        let r1 = HealthSnapshotRecord(
            capturedAt: capturedAt, metrics: HealthMetrics(hrvRMSSD: 40),
            hunger: 50, fatigue: 50, strength: 0, storedAt: earlier)
        let r2 = HealthSnapshotRecord(
            capturedAt: capturedAt, metrics: HealthMetrics(hrvRMSSD: 40),
            hunger: 50, fatigue: 50, strength: 0, storedAt: later)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        XCTAssertEqual(try store.latest()?.storedAt, later)
    }

    @MainActor
    func testNilRawMetricSurvivesRoundTrip() throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let metrics = HealthMetrics(
            restingHeartRate: nil, hrvRMSSD: 40, sleepEfficiency: nil,
            activeWorkoutEnergyKilocalories: nil)
        try seed(store, metrics, at: Date(timeIntervalSince1970: 100))

        let rec = try XCTUnwrap(try store.latest())
        XCTAssertNil(rec.restingHeartRate)
        XCTAssertEqual(rec.hrvRMSSD, 40)
        XCTAssertNil(rec.sleepEfficiency)
        XCTAssertNil(rec.activeWorkoutEnergyKilocalories)
    }

    @MainActor
    func testSavedRecordReadableFromFreshContext() throws {
        let container = try makeContainer()
        let store = HealthSnapshotStore(context: ModelContext(container))
        let capturedAt = Date(timeIntervalSince1970: 4242)
        let metrics = HealthMetrics(
            restingHeartRate: 60, hrvRMSSD: 35, sleepEfficiency: 0.8,
            activeWorkoutEnergyKilocalories: 300)
        try seed(store, metrics, at: capturedAt)

        // Read through a brand-new context on the same container to prove durability.
        let fresh = ModelContext(container)
        let rows = try fresh.fetch(FetchDescriptor<HealthSnapshotRecord>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.capturedAt, capturedAt)
        XCTAssertEqual(rows.first?.restingHeartRate, 60)
    }

    // MARK: - deriveAndStore cold start + error path (accumulation proper: HealthAccumulationStoreTests)

    @MainActor
    func testDeriveAndStoreColdStartStoresDailyInputAndStampsZone() async throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let capturedAt = Date(timeIntervalSince1970: 7000)
        let metrics = HealthMetrics(
            restingHeartRate: 55, hrvRMSSD: 50, sleepEfficiency: 0.95,
            activeWorkoutEnergyKilocalories: 1200)
        // On an empty store the baseline is empty → cold start, so accumulated values
        // equal today's DailyHealthInput.
        let expected = DailyHealthInput.derive(from: metrics, hrvBaseline: [], at: capturedAt)

        let rec = try await store.deriveAndStore(from: StubSource(metrics: metrics), at: capturedAt)
        XCTAssertEqual(rec.capturedAt, capturedAt)
        XCTAssertEqual(rec.hungerValue, expected.hunger, accuracy: 1e-9)
        XCTAssertEqual(rec.fatigueValue, expected.fatigue, accuracy: 1e-9)
        XCTAssertEqual(rec.strengthValue, expected.strength, accuracy: 1e-9)
        XCTAssertEqual(rec.restingHeartRate, 55)
        XCTAssertEqual(rec.hrvRMSSD, 50)
        XCTAssertEqual(rec.sleepEfficiency, 0.95)
        XCTAssertEqual(rec.activeWorkoutEnergyKilocalories, 1200)
        XCTAssertNotNil(
            rec.captureTimeZoneIdentifier, "capture zone is stamped for stat-day grouping")
    }

    @MainActor
    func testDeriveAndStoreIsReturnedByLatest() async throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let capturedAt = Date(timeIntervalSince1970: 8000)
        _ = try await store.deriveAndStore(
            from: StubSource(metrics: HealthMetrics(hrvRMSSD: 30)), at: capturedAt)
        XCTAssertEqual(try store.latest()?.capturedAt, capturedAt)
    }

    @MainActor
    func testDeriveAndStoreThrowsAndInsertsNothingOnSourceError() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = HealthSnapshotStore(context: context)
        // Seed an existing record so we can prove a throw leaves latest() unchanged.
        let seeded = Date(timeIntervalSince1970: 6000)
        try seed(store, HealthMetrics(hrvRMSSD: 25), at: seeded)

        do {
            _ = try await store.deriveAndStore(
                from: ThrowingSource(), at: Date(timeIntervalSince1970: 9_000_000))
            XCTFail("expected deriveAndStore to rethrow the source error")
        } catch is SourceError {
            // expected — source failure propagates
        }
        XCTAssertEqual(try store.latest()?.capturedAt, seeded)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HealthSnapshotRecord>()).count, 1)
    }
}

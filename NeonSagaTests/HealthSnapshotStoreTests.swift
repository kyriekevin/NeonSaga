import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S5 RED tests — pin HealthSnapshotRecord @Model + HealthSnapshotStore persistence
// behavior (CONTRACT S5). Fails to build until the green commit adds the model,
// the store, the ModelContainer registration, and the NeonSagaCore test dependency.
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
            restingHeartRate: 58,
            hrvRMSSD: 42,
            sleepEfficiency: 0.9,
            activeWorkoutEnergyKilocalories: 600
        )
        let snapshot = HealthSnapshot.derive(from: metrics, at: capturedAt)
        try store.save(snapshot)

        let rec = try XCTUnwrap(try store.latest())
        XCTAssertEqual(rec.capturedAt, capturedAt)
        XCTAssertEqual(rec.restingHeartRate, 58)
        XCTAssertEqual(rec.hrvRMSSD, 42)
        XCTAssertEqual(rec.sleepEfficiency, 0.9)
        XCTAssertEqual(rec.activeWorkoutEnergyKilocalories, 600)
        XCTAssertEqual(rec.hungerValue, snapshot.hunger.value)
        XCTAssertEqual(rec.fatigueValue, snapshot.fatigue.value)
        XCTAssertEqual(rec.strengthValue, snapshot.strength.value)
    }

    @MainActor
    func testLatestReturnsMostRecentByCapturedAt() throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 2000)
        let t2 = Date(timeIntervalSince1970: 3000)
        // Insert out of chronological order: t1, t2, t0.
        for t in [t1, t2, t0] {
            try store.save(HealthSnapshot.derive(from: HealthMetrics(), at: t))
        }
        XCTAssertEqual(try store.latest()?.capturedAt, t2)
    }

    @MainActor
    func testLatestTieBreaksByStoredAt() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = HealthSnapshotStore(context: context)
        let capturedAt = Date(timeIntervalSince1970: 5000)
        let snap = HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 40), at: capturedAt)
        let earlier = Date(timeIntervalSince1970: 9000)
        let later = Date(timeIntervalSince1970: 9999)
        context.insert(HealthSnapshotRecord(from: snap, storedAt: earlier))
        context.insert(HealthSnapshotRecord(from: snap, storedAt: later))
        try context.save()

        XCTAssertEqual(try store.latest()?.storedAt, later)
    }

    @MainActor
    func testNilRawMetricSurvivesRoundTrip() throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let metrics = HealthMetrics(
            restingHeartRate: nil,
            hrvRMSSD: 40,
            sleepEfficiency: nil,
            activeWorkoutEnergyKilocalories: nil
        )
        try store.save(HealthSnapshot.derive(from: metrics, at: Date(timeIntervalSince1970: 100)))

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
            restingHeartRate: 60,
            hrvRMSSD: 35,
            sleepEfficiency: 0.8,
            activeWorkoutEnergyKilocalories: 300
        )
        try store.save(HealthSnapshot.derive(from: metrics, at: capturedAt))

        // Read through a brand-new context on the same container to prove the row
        // is durably persisted, not just live in the writing context's cache.
        let fresh = ModelContext(container)
        let rows = try fresh.fetch(FetchDescriptor<HealthSnapshotRecord>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.capturedAt, capturedAt)
        XCTAssertEqual(rows.first?.restingHeartRate, 60)
    }

    // MARK: - deriveAndStore(from:at:) (behaviors 7–8)

    @MainActor
    func testDeriveAndStoreMatchesDerive() async throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let capturedAt = Date(timeIntervalSince1970: 7000)
        let metrics = HealthMetrics(
            restingHeartRate: 55,
            hrvRMSSD: 50,
            sleepEfficiency: 0.95,
            activeWorkoutEnergyKilocalories: 1200
        )
        let expected = HealthSnapshot.derive(from: metrics, at: capturedAt)

        let rec = try await store.deriveAndStore(from: StubSource(metrics: metrics), at: capturedAt)
        XCTAssertEqual(rec.capturedAt, capturedAt)
        XCTAssertEqual(rec.hungerValue, expected.hunger.value)
        XCTAssertEqual(rec.fatigueValue, expected.fatigue.value)
        XCTAssertEqual(rec.strengthValue, expected.strength.value)
        XCTAssertEqual(rec.restingHeartRate, 55)
        XCTAssertEqual(rec.activeWorkoutEnergyKilocalories, 1200)
    }

    @MainActor
    func testDeriveAndStoreIsReturnedByLatest() async throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        let capturedAt = Date(timeIntervalSince1970: 8000)
        _ = try await store.deriveAndStore(
            from: StubSource(metrics: HealthMetrics(hrvRMSSD: 30)),
            at: capturedAt
        )
        XCTAssertEqual(try store.latest()?.capturedAt, capturedAt)
    }

    @MainActor
    func testDeriveAndStoreThrowsAndInsertsNothingOnSourceError() async throws {
        let store = HealthSnapshotStore(context: ModelContext(try makeContainer()))
        do {
            _ = try await store.deriveAndStore(
                from: ThrowingSource(),
                at: Date(timeIntervalSince1970: 1)
            )
            XCTFail("expected deriveAndStore to rethrow the source error")
        } catch is SourceError {
            // expected — source failure propagates
        }
        XCTAssertNil(try store.latest())
    }
}

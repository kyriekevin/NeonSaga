import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S6 baseline tests, migrated for the S6b construction API (records built via
// HealthSnapshotRecord(capturedAt:metrics:hunger:fatigue:strength:)). Pins
// HealthSnapshotStore.recentHRVBaseline(before:limit:): excludes the record being
// scored, drops nil / non-finite HRV, windows to the most-recent `limit`,
// newest-first. (recentHRVBaseline itself is unchanged by S6b.)
final class HealthSnapshotStoreBaselineTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    private func makeStore() throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container))
    }

    /// Seeds one record carrying raw `hrv` at `capturedAt`; accumulated values are
    /// neutral placeholders (the baseline reads raw HRV only).
    @MainActor
    private func seedHRV(_ store: HealthSnapshotStore, _ hrv: Double?, at capturedAt: Date) throws {
        try store.save(
            HealthSnapshotRecord(
                capturedAt: capturedAt, metrics: HealthMetrics(hrvRMSSD: hrv),
                hunger: 50, fatigue: 50, strength: 0))
    }

    @MainActor
    func testRecentHRVBaselineExcludesScoredRecordAndNonFinite() throws {
        let store = try makeStore()
        // The record being scored (latest, at `base`) carries HRV 99 — it must NOT
        // appear in its own baseline.
        try seedHRV(store, 99, at: base)
        // Prior days (newest → oldest): finite 30, nil, NaN, finite 45.
        try seedHRV(store, 30, at: base.addingTimeInterval(-86_400))
        try seedHRV(store, nil, at: base.addingTimeInterval(-2 * 86_400))
        try seedHRV(store, .nan, at: base.addingTimeInterval(-3 * 86_400))
        try seedHRV(store, 45, at: base.addingTimeInterval(-4 * 86_400))

        // Excludes the scored record (99), the nil, and the NaN; keeps the two finite
        // priors in capturedAt-descending order.
        XCTAssertEqual(try store.recentHRVBaseline(before: base), [30.0, 45.0])
    }

    @MainActor
    func testRecentHRVBaselineRespectsLimitNewestFirst() throws {
        let store = try makeStore()
        // HRV decorrelated from recency: f(i) = (i·37 mod 97) + 1 is injective over
        // i = 1...40 and non-monotonic, so a sort-by-value impl produces a different
        // order than newest-first and an oldest-window impl produces different values.
        func hrv(_ i: Int) -> Double { Double((i * 37) % 97 + 1) }
        for i in 1...40 {
            let day = base.addingTimeInterval(-86_400 * Double(i))
            try seedHRV(store, hrv(i), at: day)
        }

        // The 28 most-recent priors are i = 1...28 (i = 1 is newest), in that order.
        XCTAssertEqual(try store.recentHRVBaseline(before: base, limit: 28), (1...28).map(hrv))
    }
}

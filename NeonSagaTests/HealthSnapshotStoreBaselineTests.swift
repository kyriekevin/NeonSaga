import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S6 RED tests — pin HealthSnapshotStore.recentHRVBaseline(before:limit:), the
// prior-day HRV baseline feeding Recovery.score (CONTRACT S6). Fails to build until
// the green commit adds the method. The baseline must exclude the record being
// scored (no z-score self-reference), drop nil / non-finite HRV, and window to the
// most-recent `limit` records before the cutoff, ordered newest-first.
final class HealthSnapshotStoreBaselineTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    private func makeStore() throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container))
    }

    @MainActor
    func testRecentHRVBaselineExcludesScoredRecordAndNonFinite() throws {
        let store = try makeStore()
        // The record being scored (latest, at `base`) carries HRV 99 — it must NOT
        // appear in its own baseline.
        try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 99), at: base))
        // Prior days (newest → oldest): finite 30, nil, NaN, finite 45.
        try store.save(
            HealthSnapshot.derive(
                from: HealthMetrics(hrvRMSSD: 30), at: base.addingTimeInterval(-86_400)))
        try store.save(
            HealthSnapshot.derive(
                from: HealthMetrics(hrvRMSSD: nil), at: base.addingTimeInterval(-2 * 86_400)))
        try store.save(
            HealthSnapshot.derive(
                from: HealthMetrics(hrvRMSSD: .nan), at: base.addingTimeInterval(-3 * 86_400)))
        try store.save(
            HealthSnapshot.derive(
                from: HealthMetrics(hrvRMSSD: 45), at: base.addingTimeInterval(-4 * 86_400)))

        // Exact newest-first array: excludes the scored record (99), the nil, and the
        // NaN; keeps the two finite priors in capturedAt-descending order.
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
            try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: hrv(i)), at: day))
        }

        // The 28 most-recent priors are i = 1...28 (i = 1 is newest), in that order.
        XCTAssertEqual(
            try store.recentHRVBaseline(before: base, limit: 28), (1...28).map(hrv))
    }
}

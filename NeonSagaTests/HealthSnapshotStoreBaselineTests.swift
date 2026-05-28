import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S6 RED tests — pin HealthSnapshotStore.recentHRVBaseline(before:limit:), the
// prior-day HRV baseline feeding Recovery.score (CONTRACT S6). Fails to build until
// the green commit adds the method. The baseline must exclude the record being
// scored (no z-score self-reference), drop nil / non-finite HRV, and window to the
// most-recent `limit` records before the cutoff.
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
        // Prior days: two finite, one nil, one NaN.
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

        let baseline = try store.recentHRVBaseline(before: base)
        XCTAssertEqual(Set(baseline), Set([30.0, 45.0]))
        XCTAssertFalse(baseline.contains(99))
    }

    @MainActor
    func testRecentHRVBaselineRespectsLimitNewestFirst() throws {
        let store = try makeStore()
        // 40 prior days, HRV i at base − i days (i = 1 is the newest prior).
        for i in 1...40 {
            let day = base.addingTimeInterval(-86_400 * Double(i))
            try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: Double(i)), at: day))
        }

        let baseline = try store.recentHRVBaseline(before: base, limit: 28)
        XCTAssertEqual(baseline.count, 28)
        // The 28 most-recent priors are i = 1...28 → HRV {1...28}; the oldest 12 drop.
        XCTAssertEqual(Set(baseline), Set((1...28).map(Double.init)))
    }
}

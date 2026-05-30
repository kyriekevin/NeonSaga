import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

/// S7 RED — level-up takeover DETECTION in `HealthDetailViewModel`. Asserts the VM
/// enqueues `SubStatLevelCrossing` events when a freshly displayed snapshot crosses an
/// LV threshold vs. the previously displayed values, stays silent on first load, and
/// advances / clears the FIFO queue. Presentation (the 0.8s animation + haptic) is
/// `LevelUpTakeoverView`'s responsibility and is NOT unit-tested here — per ADR-003 it
/// is covered by the Layer-0 lifecycle checklist, not by structural assertions.
final class LevelUpViewModelTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    private func makeStore() throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container))
    }

    /// Saves one record with explicit ACCUMULATED sub-stat values (the VM displays them
    /// directly via `latest()`); `HealthMetrics()` keeps Recovery/Strain out of the way.
    @MainActor
    private func seed(
        _ store: HealthSnapshotStore, at when: Date,
        hunger: Double, fatigue: Double, strength: Double
    ) throws {
        try store.save(
            HealthSnapshotRecord(
                capturedAt: when, metrics: HealthMetrics(),
                hunger: hunger, fatigue: fatigue, strength: strength))
    }

    private func xing(_ s: SubStat, _ old: Int, _ new: Int) -> SubStatLevelCrossing {
        SubStatLevelCrossing(substat: s, crossing: LevelCrossing(oldLevel: old, newLevel: new))
    }

    // MARK: - Init / first load is silent (required behavior 3)

    @MainActor
    func testInitWithDataEnqueuesNothing() throws {
        let store = try makeStore()
        try seed(store, at: base, hunger: 10, fatigue: 10, strength: 10)

        let vm = HealthDetailViewModel(store: store)

        XCTAssertTrue(vm.levelUpQueue.isEmpty)
        XCTAssertNil(vm.currentLevelUp)
    }

    @MainActor
    func testNoDataInitLeavesQueueEmpty() throws {
        let vm = HealthDetailViewModel(store: try makeStore())

        XCTAssertTrue(vm.levelUpQueue.isEmpty)
        XCTAssertNil(vm.currentLevelUp)
    }

    @MainActor
    func testInitWithPriorHistoryStaysSilent() throws {
        let store = try makeStore()
        // Two records ALREADY persisted before the VM exists: an older (10,10,10) and a
        // newer (30,10,30) that WOULD be a crossing if detection diffed store history.
        // The detection seam is the VM's previously-DISPLAYED values (nil at init), so
        // init must stay silent — it must NOT compare latest vs. second-latest in the
        // store (Codex tests-review item 5).
        try seed(store, at: base, hunger: 10, fatigue: 10, strength: 10)
        try seed(
            store, at: base.addingTimeInterval(60), hunger: 30, fatigue: 10, strength: 30)

        let vm = HealthDetailViewModel(store: store)

        XCTAssertTrue(vm.levelUpQueue.isEmpty)
        XCTAssertNil(vm.currentLevelUp)
    }

    // MARK: - refresh detects an upward crossing (required behavior 4)

    @MainActor
    func testRefreshAfterUpwardCrossingEnqueues() throws {
        let store = try makeStore()
        try seed(store, at: base, hunger: 40, fatigue: 50, strength: 40)
        let vm = HealthDetailViewModel(store: store)  // baseline (40,50,40), silent

        // A later record (becomes `latest()`) where only STRENGTH crosses 40→60.
        try seed(
            store, at: base.addingTimeInterval(60), hunger: 40, fatigue: 50, strength: 60)
        vm.refresh()

        let current = try XCTUnwrap(vm.currentLevelUp)
        XCTAssertEqual(current.substat, .strength)
        XCTAssertEqual(current.crossing, LevelCrossing(oldLevel: 40, newLevel: 60))
        XCTAssertEqual(vm.levelUpQueue.count, 1)
    }

    @MainActor
    func testValueMoveWithoutLevelChangeDoesNotEnqueue() throws {
        let store = try makeStore()
        try seed(store, at: base, hunger: 50, fatigue: 50, strength: 50)
        let vm = HealthDetailViewModel(store: store)

        // Same-LV nudge: 50 → 50.4 all stay LV 50.
        try seed(
            store, at: base.addingTimeInterval(60), hunger: 50.4, fatigue: 50.4, strength: 50.4)
        vm.refresh()

        XCTAssertTrue(vm.levelUpQueue.isEmpty)
        XCTAssertNil(vm.currentLevelUp)
    }

    // MARK: - FIFO advancement through multiple crossings (Codex 4d)

    @MainActor
    func testDismissAdvancesThroughMultipleCrossings() throws {
        let store = try makeStore()
        try seed(store, at: base, hunger: 10, fatigue: 10, strength: 10)
        let vm = HealthDetailViewModel(store: store)

        // Exactly TWO cross: hunger 10→30 and strength 10→30; fatigue static at LV 10.
        try seed(
            store, at: base.addingTimeInterval(60), hunger: 30, fatigue: 10, strength: 30)
        vm.refresh()

        // Assert the full SubStatLevelCrossing payloads (substat + old/new LV), not just
        // the substat — a wrong impl could enqueue the right substats with wrong levels
        // (Codex tests-review item 4).
        XCTAssertEqual(vm.levelUpQueue.count, 2)
        XCTAssertEqual(vm.currentLevelUp, xing(.hunger, 10, 30))
        vm.dismissCurrentLevelUp()
        XCTAssertEqual(vm.currentLevelUp, xing(.strength, 10, 30))
        vm.dismissCurrentLevelUp()
        XCTAssertNil(vm.currentLevelUp)
        XCTAssertTrue(vm.levelUpQueue.isEmpty)
    }

    // MARK: - Baseline reset across a data gap (required behavior 6 / Codex 4c)

    @MainActor
    func testBaselineResetAfterDataDisappearsThenReturns() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = HealthSnapshotStore(context: context)

        let recordA = HealthSnapshotRecord(
            capturedAt: base, metrics: HealthMetrics(),
            hunger: 10, fatigue: 10, strength: 10)
        context.insert(recordA)
        try context.save()

        let vm = HealthDetailViewModel(store: store)  // baseline (10,10,10), silent
        XCTAssertTrue(vm.levelUpQueue.isEmpty)

        // Data disappears → the no-data branch must reset the baseline.
        context.delete(recordA)
        try context.save()
        vm.refresh()
        XCTAssertNil(vm.currentLevelUp)

        // A new first-data record whose values WOULD cross vs. A must NOT fire — the
        // baseline was reset across the gap, so B is a fresh first compute (silent).
        let recordB = HealthSnapshotRecord(
            capturedAt: base.addingTimeInterval(120), metrics: HealthMetrics(),
            hunger: 90, fatigue: 90, strength: 90)
        context.insert(recordB)
        try context.save()
        vm.refresh()

        XCTAssertTrue(vm.levelUpQueue.isEmpty)
        XCTAssertNil(vm.currentLevelUp)
    }
}

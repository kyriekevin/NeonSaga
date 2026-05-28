import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S6 RED tests — pin HealthDetailViewModel's display-model mapping (CONTRACT S6).
// Asserts the VM's semantic fields (band enum + numeric fractions + placeholder
// strings), NOT Color or rendered geometry. Fails to build until the green commit
// adds HealthDetailViewModel, SubStatRow, and HealthSnapshotStore.recentHRVBaseline.
final class HealthDetailViewModelTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    private func makeStore() throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container))
    }

    /// Save `count` prior-day snapshots strictly before `base`, each with finite HRV.
    @MainActor
    private func seedPriorDays(_ store: HealthSnapshotStore, count: Int) throws {
        guard count > 0 else { return }
        for i in 1...count {
            let day = base.addingTimeInterval(-86_400 * Double(i))
            try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 40), at: day))
        }
    }

    // MARK: - Empty store (behavior 6)

    @MainActor
    func testEmptyStoreShowsCalibratingAndNoData() throws {
        let vm = HealthDetailViewModel(store: try makeStore())
        XCTAssertEqual(vm.recovery, .calibrating(daysOfData: 0))
        XCTAssertNil(vm.recoveryRingFraction)
        XCTAssertEqual(vm.strain, .noData)
        XCTAssertNil(vm.strainFraction)
        XCTAssertTrue(vm.subStats.isEmpty)
        XCTAssertNil(vm.healthValue)
        XCTAssertNil(vm.healthLevel)
        XCTAssertFalse(vm.hasData)
    }

    // MARK: - Recovery (behaviors 2–3)

    @MainActor
    func testScoredRecoveryWhenFourteenPriorSamples() throws {
        let store = try makeStore()
        try seedPriorDays(store, count: 14)
        try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 45), at: base))

        let vm = HealthDetailViewModel(store: store)
        guard case .scored(let value, let band) = vm.recovery else {
            return XCTFail("expected .scored with 14 prior baseline samples")
        }
        XCTAssertTrue(value >= 0 && value <= 100)
        XCTAssertEqual(band, Recovery.band(for: value))
    }

    @MainActor
    func testThirteenPriorSamplesCalibratesAndExcludesLatest() throws {
        let store = try makeStore()
        try seedPriorDays(store, count: 13)
        // Latest record carries a finite HRV too. If the scored record's own HRV were
        // folded into its baseline, 13 + 1 = 14 would falsely score; .calibrating(13)
        // proves recentHRVBaseline excludes the record being scored (Codex B2).
        try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 45), at: base))

        let vm = HealthDetailViewModel(store: store)
        XCTAssertEqual(vm.recovery, .calibrating(daysOfData: 13))
        XCTAssertNil(vm.recoveryRingFraction)
    }

    @MainActor
    func testRecoveryRingFractionMatchesScore() throws {
        let store = try makeStore()
        try seedPriorDays(store, count: 14)
        try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 45), at: base))

        let vm = HealthDetailViewModel(store: store)
        guard case .scored(let value, _) = vm.recovery else {
            return XCTFail("expected .scored")
        }
        let fraction = try XCTUnwrap(vm.recoveryRingFraction)
        XCTAssertEqual(fraction, value / 100.0, accuracy: 1e-9)
    }

    // MARK: - Strain (behavior 4)

    @MainActor
    func testStrainScoredFromLatestWorkoutEnergy() throws {
        let store = try makeStore()
        try store.save(
            HealthSnapshot.derive(
                from: HealthMetrics(activeWorkoutEnergyKilocalories: 300), at: base))

        let vm = HealthDetailViewModel(store: store)
        guard case .scored(let value) = vm.strain else {
            return XCTFail("expected .scored strain")
        }
        XCTAssertTrue(value >= 0 && value <= 21)
        let fraction = try XCTUnwrap(vm.strainFraction)
        XCTAssertEqual(fraction, value / 21.0, accuracy: 1e-9)
    }

    @MainActor
    func testStrainNoDataWhenWorkoutEnergyMissing() throws {
        let store = try makeStore()
        try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 40), at: base))

        let vm = HealthDetailViewModel(store: store)
        XCTAssertEqual(vm.strain, .noData)
        XCTAssertNil(vm.strainFraction)
    }

    // MARK: - Sub-stats (behavior 5)

    @MainActor
    func testSubStatRowsMatchLatestRecord() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = HealthSnapshotStore(context: context)
        let snap = HealthSnapshot.derive(from: HealthMetrics(), at: base)
        let rec = HealthSnapshotRecord(from: snap)
        rec.capturedAt = base
        rec.hungerValue = 40
        rec.fatigueValue = 70
        rec.strengthValue = 88
        context.insert(rec)
        try context.save()

        let vm = HealthDetailViewModel(store: store)
        XCTAssertEqual(vm.subStats.count, 3)

        XCTAssertEqual(vm.subStats[0].substat, .hunger)
        XCTAssertEqual(vm.subStats[0].value, 40, accuracy: 1e-9)
        XCTAssertEqual(vm.subStats[0].level, Level.of(40))
        XCTAssertEqual(vm.subStats[0].fillFraction, 0.40, accuracy: 1e-9)

        XCTAssertEqual(vm.subStats[1].substat, .fatigue)
        XCTAssertEqual(vm.subStats[1].value, 70, accuracy: 1e-9)
        XCTAssertEqual(vm.subStats[1].level, Level.of(70))

        XCTAssertEqual(vm.subStats[2].substat, .strength)
        XCTAssertEqual(vm.subStats[2].value, 88, accuracy: 1e-9)
        XCTAssertEqual(vm.subStats[2].level, Level.of(88))

        XCTAssertEqual(
            vm.healthValue, HealthStat.value(hunger: 40, fatigue: 70, strength: 88))
        XCTAssertEqual(
            vm.healthLevel, HealthStat.level(hunger: 40, fatigue: 70, strength: 88))
    }

    @MainActor
    func testHungerRendersNeutralStageOneValue() throws {
        let store = try makeStore()
        try store.save(
            HealthSnapshot.derive(
                from: HealthMetrics(activeWorkoutEnergyKilocalories: 200), at: base))

        let vm = HealthDetailViewModel(store: store)
        let hunger = try XCTUnwrap(vm.subStats.first { $0.substat == .hunger })
        XCTAssertEqual(hunger.value, 50, accuracy: 1e-9)
    }

    // MARK: - refresh() + placeholder slots (behaviors 1, 7)

    @MainActor
    func testRefreshPicksUpNewlySavedSnapshot() throws {
        let store = try makeStore()
        let vm = HealthDetailViewModel(store: store)
        XCTAssertFalse(vm.hasData)

        try store.save(HealthSnapshot.derive(from: HealthMetrics(hrvRMSSD: 40), at: base))
        vm.refresh()

        XCTAssertTrue(vm.hasData)
        XCTAssertEqual(vm.subStats.count, 3)
    }

    @MainActor
    func testSleepAndAIBriefPlaceholdersPresent() throws {
        let vm = HealthDetailViewModel(store: try makeStore())
        XCTAssertFalse(vm.sleepPlaceholder.isEmpty)
        XCTAssertFalse(vm.aiBriefPlaceholder.isEmpty)
    }
}

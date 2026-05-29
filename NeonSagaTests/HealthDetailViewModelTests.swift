import NeonSagaCore
import SwiftData
import XCTest

@testable import NeonSaga

// S6 VM display tests, migrated for the S6b construction API (records built via
// HealthSnapshotRecord(capturedAt:metrics:hunger:fatigue:strength:)). Asserts the VM's
// semantic fields (band enum + numeric fractions + placeholder strings), NOT Color or
// geometry. Recovery / Strain read the record's raw metrics; sub-stat rows read the
// record's ACCUMULATED stored values — both unchanged in meaning here.
final class HealthDetailViewModelTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    private func makeStore() throws -> HealthSnapshotStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HealthSnapshotRecord.self, configurations: config)
        return HealthSnapshotStore(context: ModelContext(container))
    }

    /// Seeds one record (raw metrics + neutral-placeholder accumulated values) at `at`.
    @MainActor
    private func seed(
        _ store: HealthSnapshotStore, _ metrics: HealthMetrics, at when: Date,
        hunger: Double = 50, fatigue: Double = 50, strength: Double = 0
    ) throws {
        try store.save(
            HealthSnapshotRecord(
                capturedAt: when, metrics: metrics,
                hunger: hunger, fatigue: fatigue, strength: strength))
    }

    /// Save `count` prior-day records strictly before `base`, each with raw HRV 40.
    @MainActor
    private func seedPriorDays(_ store: HealthSnapshotStore, count: Int) throws {
        guard count > 0 else { return }
        for i in 1...count {
            let day = base.addingTimeInterval(-86_400 * Double(i))
            try seed(store, HealthMetrics(hrvRMSSD: 40), at: day)
        }
    }

    /// Seed 14 prior days with mean 40 / population std 10 (7×30 + 7×50) plus a latest
    /// record at `base` whose today-HRV 50 is exactly one std above the baseline mean.
    /// Recovery then scores to a deterministic, non-round value: z = 1 → hrvTerm = 65;
    /// RHR / sleep absent → neutral 50; value = 0.5·65 + 0.25·50 + 0.25·50 = 57.5
    /// (band YELLOW, ring fraction 0.575). A hard-coded stub cannot guess this.
    @MainActor
    private func seedScoredRecovery(_ store: HealthSnapshotStore) throws {
        for i in 1...14 {
            let day = base.addingTimeInterval(-86_400 * Double(i))
            let hrv: Double = i <= 7 ? 30 : 50
            try seed(store, HealthMetrics(hrvRMSSD: hrv), at: day)
        }
        try seed(store, HealthMetrics(hrvRMSSD: 50), at: base)
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
        try seedScoredRecovery(store)

        let vm = HealthDetailViewModel(store: store)
        guard case .scored(let value, let band) = vm.recovery else {
            return XCTFail("expected .scored with 14 prior baseline samples")
        }
        XCTAssertEqual(value, 57.5, accuracy: 1e-9)
        XCTAssertEqual(band, .yellow)
        XCTAssertEqual(band, Recovery.band(for: value))
    }

    @MainActor
    func testThirteenPriorSamplesCalibratesAndExcludesLatest() throws {
        let store = try makeStore()
        try seedPriorDays(store, count: 13)
        // Latest record carries a finite HRV too. If the scored record's own HRV were
        // folded into its baseline, 13 + 1 = 14 would falsely score; .calibrating(13)
        // proves recentHRVBaseline excludes the record being scored (Codex B2).
        try seed(store, HealthMetrics(hrvRMSSD: 45), at: base)

        let vm = HealthDetailViewModel(store: store)
        XCTAssertEqual(vm.recovery, .calibrating(daysOfData: 13))
        XCTAssertNil(vm.recoveryRingFraction)
    }

    @MainActor
    func testNilTodayHRVCalibratesDespiteSufficientBaseline() throws {
        let store = try makeStore()
        try seedPriorDays(store, count: 14)
        // Latest record has NO today-HRV (workout energy only). Recovery.score gates on
        // a finite today-HRV in addition to ≥14 baseline samples, so this must calibrate
        // at the full baseline count (Codex tests-review F2).
        try seed(store, HealthMetrics(activeWorkoutEnergyKilocalories: 100), at: base)

        let vm = HealthDetailViewModel(store: store)
        XCTAssertEqual(vm.recovery, .calibrating(daysOfData: 14))
        XCTAssertNil(vm.recoveryRingFraction)
    }

    @MainActor
    func testRecoveryRingFractionMatchesScore() throws {
        let store = try makeStore()
        try seedScoredRecovery(store)

        let vm = HealthDetailViewModel(store: store)
        let fraction = try XCTUnwrap(vm.recoveryRingFraction)
        XCTAssertEqual(fraction, 0.575, accuracy: 1e-9)
    }

    // MARK: - Strain (behavior 4)

    @MainActor
    func testStrainScoredFromLatestWorkoutEnergy() throws {
        let store = try makeStore()
        // 300 kcal == Strain's half-saturation constant → 21·300/600 == 10.5 exactly.
        try seed(store, HealthMetrics(activeWorkoutEnergyKilocalories: 300), at: base)

        let vm = HealthDetailViewModel(store: store)
        guard case .scored(let value) = vm.strain else {
            return XCTFail("expected .scored strain")
        }
        XCTAssertEqual(value, 10.5, accuracy: 1e-9)
        let fraction = try XCTUnwrap(vm.strainFraction)
        XCTAssertEqual(fraction, 0.5, accuracy: 1e-9)
    }

    @MainActor
    func testStrainNoDataWhenWorkoutEnergyMissing() throws {
        let store = try makeStore()
        try seed(store, HealthMetrics(hrvRMSSD: 40), at: base)

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
        // Seed a record with explicit ACCUMULATED sub-stat values; the VM displays them.
        let rec = HealthSnapshotRecord(
            capturedAt: base, metrics: HealthMetrics(),
            hunger: 40, fatigue: 70, strength: 88)
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
        XCTAssertEqual(vm.subStats[1].fillFraction, 0.70, accuracy: 1e-9)

        XCTAssertEqual(vm.subStats[2].substat, .strength)
        XCTAssertEqual(vm.subStats[2].value, 88, accuracy: 1e-9)
        XCTAssertEqual(vm.subStats[2].level, Level.of(88))
        XCTAssertEqual(vm.subStats[2].fillFraction, 0.88, accuracy: 1e-9)

        XCTAssertEqual(
            vm.healthValue, HealthStat.value(hunger: 40, fatigue: 70, strength: 88))
        XCTAssertEqual(
            vm.healthLevel, HealthStat.level(hunger: 40, fatigue: 70, strength: 88))
    }

    @MainActor
    func testHungerRendersNeutralStageOneValue() throws {
        let store = try makeStore()
        // A real record carries the accumulated HUNGER placeholder (50) until Stage 3.
        try seed(store, HealthMetrics(activeWorkoutEnergyKilocalories: 200), at: base, hunger: 50)

        let vm = HealthDetailViewModel(store: store)
        let hunger = try XCTUnwrap(vm.subStats.first { $0.substat == .hunger })
        XCTAssertEqual(hunger.value, 50, accuracy: 1e-9)
    }

    // MARK: - refresh() + placeholder slots (behavior 7)

    @MainActor
    func testRefreshPicksUpNewlySavedSnapshot() throws {
        let store = try makeStore()
        let vm = HealthDetailViewModel(store: store)
        XCTAssertFalse(vm.hasData)

        try seed(store, HealthMetrics(hrvRMSSD: 40), at: base)
        vm.refresh()

        XCTAssertTrue(vm.hasData)
        XCTAssertEqual(vm.subStats.count, 3)
    }

    @MainActor
    func testSleepAndAIBriefPlaceholdersPresent() throws {
        let vm = HealthDetailViewModel(store: try makeStore())
        XCTAssertTrue(vm.sleepPlaceholder.contains("S8"))
        XCTAssertTrue(vm.aiBriefPlaceholder.contains("S9"))
    }
}

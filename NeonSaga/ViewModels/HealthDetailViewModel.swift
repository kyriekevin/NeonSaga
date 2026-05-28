import NeonSagaCore
import Observation

/// A row in the HEALTH sub-stats card.
struct SubStatRow {
    let substat: SubStat
    let value: Double
    let level: Int
    /// Bar fill fraction: `min(max(value / 100, 0), 1)`.
    let fillFraction: Double
}

/// View model for the HEALTH detail card stack.
///
/// `@MainActor` because it reads from a `HealthSnapshotStore` (also `@MainActor`)
/// and publishes to SwiftUI. `@Observable` so the view tracks only the properties
/// it actually reads.
@MainActor @Observable final class HealthDetailViewModel {
    private let store: HealthSnapshotStore

    // MARK: - Published state

    var recovery: RecoveryResult = .calibrating(daysOfData: 0)
    var strain: StrainResult = .noData
    var subStats: [SubStatRow] = []
    var healthValue: Double? = nil
    var healthLevel: Int? = nil
    var hasData: Bool = false

    /// Placeholder slot label for the Sleep card (S8 deliverable).
    let sleepPlaceholder: String = "Sleep architecture — arrives in S8"

    /// Placeholder slot label for the AI-brief sub-slot in the Recovery card (S9).
    let aiBriefPlaceholder: String = "AI brief — arrives in S9"

    // MARK: - Computed fractions

    /// Ring fill fraction for the Recovery hero card.
    /// `nil` when `.calibrating`; `value/100` (clamped 0–1) when `.scored`.
    var recoveryRingFraction: Double? {
        guard case .scored(let value, _) = recovery else { return nil }
        return min(max(value / 100, 0), 1)
    }

    /// Bar fill fraction for the Strain card.
    /// `nil` when `.noData`; `value/21` (clamped 0–1) when `.scored`.
    var strainFraction: Double? {
        guard case .scored(let value) = strain else { return nil }
        return min(max(value / 21, 0), 1)
    }

    // MARK: - Init

    init(store: HealthSnapshotStore) {
        self.store = store
        compute()
    }

    // MARK: - refresh

    /// Re-reads the store and recomputes the display model.
    func refresh() {
        compute()
    }

    // MARK: - Private compute

    private func compute() {
        guard let latest = try? store.latest() else {
            recovery = .calibrating(daysOfData: 0)
            strain = .noData
            subStats = []
            healthValue = nil
            healthLevel = nil
            hasData = false
            return
        }

        let snapshot = HealthDetailAdapter.snapshot(from: latest)
        let baseline = (try? store.recentHRVBaseline(before: latest.capturedAt)) ?? []
        recovery = Recovery.score(for: snapshot, hrvBaseline: baseline)
        strain = Strain.score(for: snapshot)

        let h = latest.hungerValue
        let f = latest.fatigueValue
        let s = latest.strengthValue

        subStats = [
            SubStatRow(
                substat: .hunger,
                value: h,
                level: Level.of(h),
                fillFraction: min(max(h / 100, 0), 1)
            ),
            SubStatRow(
                substat: .fatigue,
                value: f,
                level: Level.of(f),
                fillFraction: min(max(f / 100, 0), 1)
            ),
            SubStatRow(
                substat: .strength,
                value: s,
                level: Level.of(s),
                fillFraction: min(max(s / 100, 0), 1)
            ),
        ]

        healthValue = HealthStat.value(hunger: h, fatigue: f, strength: s)
        healthLevel = HealthStat.level(hunger: h, fatigue: f, strength: s)
        hasData = true
    }
}

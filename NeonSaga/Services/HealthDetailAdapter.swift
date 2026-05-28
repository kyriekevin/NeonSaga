import Foundation
import NeonSagaCore

/// Reconstructs a `HealthSnapshot` from a persisted `HealthSnapshotRecord`.
///
/// Single testable reconstruction site (CONTRACT S6 / Codex Q2). Recovery and
/// Strain read only `.metrics`, so re-derived sub-stat values are irrelevant to
/// scoring; sub-stat display uses the record's own stored values directly.
enum HealthDetailAdapter {
    static func snapshot(from record: HealthSnapshotRecord) -> HealthSnapshot {
        let metrics = HealthMetrics(
            restingHeartRate: record.restingHeartRate,
            hrvRMSSD: record.hrvRMSSD,
            sleepEfficiency: record.sleepEfficiency,
            activeWorkoutEnergyKilocalories: record.activeWorkoutEnergyKilocalories
        )
        return HealthSnapshot.derive(from: metrics, at: record.capturedAt)
    }
}

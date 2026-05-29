import Foundation
import NeonSagaCore

/// Reconstructs a `HealthSnapshot` (metrics carrier) from a persisted record.
///
/// S6b: `HealthSnapshot` is now a metrics carrier (no derived sub-stats), so this
/// just bundles the record's raw metrics + capturedAt. Recovery / Strain read only
/// `.metrics`; sub-stat display uses the record's own ACCUMULATED stored values.
enum HealthDetailAdapter {
    static func snapshot(from record: HealthSnapshotRecord) -> HealthSnapshot {
        let metrics = HealthMetrics(
            restingHeartRate: record.restingHeartRate,
            hrvRMSSD: record.hrvRMSSD,
            sleepEfficiency: record.sleepEfficiency,
            activeWorkoutEnergyKilocalories: record.activeWorkoutEnergyKilocalories
        )
        return HealthSnapshot(capturedAt: record.capturedAt, metrics: metrics)
    }
}

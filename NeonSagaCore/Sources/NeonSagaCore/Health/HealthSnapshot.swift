import Foundation

/// Timestamped raw Apple Health signals — the metrics carrier consumed by
/// `Recovery` / `Strain` scoring.
///
/// S6b (ADR-002): the sub-stat *derivation* moved to `DailyHealthInput.derive`
/// (today's instantaneous inputs), and the *accumulated* character-stat values
/// live on `HealthSnapshotRecord`. This type therefore carries only the raw
/// signals + their capture time — it intentionally has NO sub-stat values and
/// NO `healthValue` / `healthLevel` aggregate (the type-boundary mandate).
public struct HealthSnapshot {
    public let capturedAt: Date
    public let metrics: HealthMetrics

    public init(capturedAt: Date, metrics: HealthMetrics) {
        self.capturedAt = capturedAt
        self.metrics = metrics
    }
}

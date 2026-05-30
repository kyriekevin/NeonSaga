import Foundation
import NeonSagaCore
import SwiftData

@Model final class HealthSnapshotRecord {
    var capturedAt: Date = Date.distantPast
    var storedAt: Date = Date.distantPast
    /// S6b (ADR-002): time zone at capture, so stat-day grouping uses the local
    /// date label `(y,m,d)` in the zone the record was captured in (travel/DST-robust).
    /// Optional + nil-default → CloudKit-safe, SwiftData lightweight migration.
    var captureTimeZoneIdentifier: String?
    var restingHeartRate: Double?
    var hrvRMSSD: Double?
    var sleepEfficiency: Double?
    var activeWorkoutEnergyKilocalories: Double?
    // S8 sleep architecture fields — optional, nil-defaulted (CloudKit-safe,
    // SwiftData lightweight migration; §5). Appended after the original four raw-metrics
    // fields so existing call sites stay source-compatible.
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var lightSleepMinutes: Double?
    var timeInBedMinutes: Double?
    var wakeEventsCount: Int?
    /// S6b (ADR-002): these are now the ACCUMULATED (EWMA, time-aware) character-stat
    /// values carried forward across records — NOT the instantaneous daily inputs.
    var hungerValue: Double = 0
    var fatigueValue: Double = 0
    var strengthValue: Double = 0

    /// Builds a record from the raw metrics carrier + the ACCUMULATED sub-stat values.
    /// The store computes the accumulation (EWMA over the prior record + today's
    /// `DailyHealthInput`), then constructs the record with the resulting values.
    init(
        capturedAt: Date,
        metrics: HealthMetrics,
        hunger: Double,
        fatigue: Double,
        strength: Double,
        storedAt: Date = Date(),
        captureTimeZoneIdentifier: String? = nil
    ) {
        self.capturedAt = capturedAt
        self.storedAt = storedAt
        self.captureTimeZoneIdentifier = captureTimeZoneIdentifier
        self.restingHeartRate = metrics.restingHeartRate
        self.hrvRMSSD = metrics.hrvRMSSD
        self.sleepEfficiency = metrics.sleepEfficiency
        self.activeWorkoutEnergyKilocalories = metrics.activeWorkoutEnergyKilocalories
        self.deepSleepMinutes = metrics.deepSleepMinutes
        self.remSleepMinutes = metrics.remSleepMinutes
        self.lightSleepMinutes = metrics.lightSleepMinutes
        self.timeInBedMinutes = metrics.timeInBedMinutes
        self.wakeEventsCount = metrics.wakeEventsCount
        self.hungerValue = hunger
        self.fatigueValue = fatigue
        self.strengthValue = strength
    }
}

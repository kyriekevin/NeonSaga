import Foundation

/// Point-in-time raw Apple Health signals feeding the HEALTH domain (S2 CONTRACT).
/// Every field optional — a missing HealthKit sample is `nil`, never `0`.
/// Additively extensible: new fields must keep a `nil` default so call sites and
/// the S2 contract stay source-compatible (S3 Recovery baseline / S4 Strain HR-zone).
public struct HealthMetrics: Equatable {
    public let restingHeartRate: Double?  // bpm
    public let hrvRMSSD: Double?  // ms
    public let sleepEfficiency: Double?  // 0...1 fraction
    public let activeWorkoutEnergyKilocalories: Double?  // kcal

    public init(
        restingHeartRate: Double? = nil,
        hrvRMSSD: Double? = nil,
        sleepEfficiency: Double? = nil,
        activeWorkoutEnergyKilocalories: Double? = nil
    ) {
        self.restingHeartRate = restingHeartRate
        self.hrvRMSSD = hrvRMSSD
        self.sleepEfficiency = sleepEfficiency
        self.activeWorkoutEnergyKilocalories = activeWorkoutEnergyKilocalories
    }
}

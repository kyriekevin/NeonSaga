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

    // S8 sleep architecture fields (appended after the original four — call sites stay
    // source-compatible). Note: Apple `HKCategoryValueSleepAnalysis.asleepCore` maps
    // to "Light" here per ROADMAP §2 vocabulary; the mapping is applied in the S5b reader.
    public let deepSleepMinutes: Double?
    public let remSleepMinutes: Double?
    /// `asleepCore` (Apple HealthKit) → Light here (ROADMAP §2). S5b reader applies the map.
    public let lightSleepMinutes: Double?
    public let timeInBedMinutes: Double?
    public let wakeEventsCount: Int?

    public init(
        restingHeartRate: Double? = nil,
        hrvRMSSD: Double? = nil,
        sleepEfficiency: Double? = nil,
        activeWorkoutEnergyKilocalories: Double? = nil,
        deepSleepMinutes: Double? = nil,
        remSleepMinutes: Double? = nil,
        lightSleepMinutes: Double? = nil,
        timeInBedMinutes: Double? = nil,
        wakeEventsCount: Int? = nil
    ) {
        self.restingHeartRate = restingHeartRate
        self.hrvRMSSD = hrvRMSSD
        self.sleepEfficiency = sleepEfficiency
        self.activeWorkoutEnergyKilocalories = activeWorkoutEnergyKilocalories
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.timeInBedMinutes = timeInBedMinutes
        self.wakeEventsCount = wakeEventsCount
    }
}

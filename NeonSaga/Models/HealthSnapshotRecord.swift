import Foundation
import NeonSagaCore
import SwiftData

@Model final class HealthSnapshotRecord {
    var capturedAt: Date = Date.distantPast
    var storedAt: Date = Date.distantPast
    var restingHeartRate: Double?
    var hrvRMSSD: Double?
    var sleepEfficiency: Double?
    var activeWorkoutEnergyKilocalories: Double?
    var hungerValue: Double = 0
    var fatigueValue: Double = 0
    var strengthValue: Double = 0

    init(from snapshot: HealthSnapshot, storedAt: Date = Date()) {
        self.capturedAt = snapshot.capturedAt
        self.storedAt = storedAt
        self.restingHeartRate = snapshot.metrics.restingHeartRate
        self.hrvRMSSD = snapshot.metrics.hrvRMSSD
        self.sleepEfficiency = snapshot.metrics.sleepEfficiency
        self.activeWorkoutEnergyKilocalories = snapshot.metrics.activeWorkoutEnergyKilocalories
        self.hungerValue = snapshot.hunger.value
        self.fatigueValue = snapshot.fatigue.value
        self.strengthValue = snapshot.strength.value
    }
}

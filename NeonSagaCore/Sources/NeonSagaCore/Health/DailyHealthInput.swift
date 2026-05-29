import Foundation

/// Today's per-sub-stat daily INPUTS to the HEALTH accumulation (S6b / ADR-002
/// Decision 3) — instantaneous readings, NOT the accumulated character stats.
///
/// Deliberately exposes NO `healthValue` / `healthLevel` aggregate: aggregating
/// daily inputs would not be a character stat (the ADR-002 type-boundary
/// mandate, enforced structurally). The HEALTH display + `LevelUp.detect` read
/// the record's ACCUMULATED values, never this carrier.
public struct DailyHealthInput {
    public let capturedAt: Date
    public let hunger: Double  // 0...100 — neutral-50 placeholder until Stage 3
    public let fatigue: Double  // 0...100 — baseline-relative HRV recovery reading
    public let strength: Double  // 0...100 — normalized workout energy

    public init(capturedAt: Date, hunger: Double, fatigue: Double, strength: Double) {
        self.capturedAt = capturedAt
        self.hunger = hunger
        self.fatigue = fatigue
        self.strength = strength
    }

    /// Pure mapping from raw metrics (+ HRV baseline for FATIGUE) to today's inputs.
    /// - STRENGTH ← normalized workout energy (kcal / 6, clamped 0...100; nil → 0).
    /// - FATIGUE  ← `Recovery.hrvRecoveryReading(todayHRV:baseline:)` (neutral 50 calibrating).
    /// - HUNGER   ← 50 placeholder.
    public static func derive(
        from metrics: HealthMetrics, hrvBaseline: [Double], at capturedAt: Date
    ) -> DailyHealthInput {
        // STRENGTH ← normalized workout energy (kcal / 6, clamped 0...100; nil or non-finite → 0).
        let strength: Double
        if let raw = metrics.activeWorkoutEnergyKilocalories, raw.isFinite {
            strength = (raw / 6.0).clamped(to: 0...100)
        } else {
            strength = 0
        }

        // FATIGUE ← baseline-relative HRV recovery reading (neutral 50 while calibrating).
        let fatigue = Recovery.hrvRecoveryReading(
            todayHRV: metrics.hrvRMSSD, baseline: hrvBaseline)

        // HUNGER ← neutral placeholder (Stage 3 will supply a real source).
        let hunger: Double = 50.0

        return DailyHealthInput(
            capturedAt: capturedAt, hunger: hunger, fatigue: fatigue, strength: strength)
    }
}

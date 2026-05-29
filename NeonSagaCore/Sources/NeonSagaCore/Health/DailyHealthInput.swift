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
    public let hunger: Double    // 0...100 — neutral-50 placeholder until Stage 3
    public let fatigue: Double   // 0...100 — baseline-relative HRV recovery reading
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
        // S6b RED stub — GREEN implements the three daily-input mappings. All-zeros
        // fails the assertions (FATIGUE == 50 calibrating, HUNGER == 50, FATIGUE
        // increases with today-HRV) so `make test-core` stays red until the body lands.
        DailyHealthInput(capturedAt: capturedAt, hunger: 0, fatigue: 0, strength: 0)
    }
}

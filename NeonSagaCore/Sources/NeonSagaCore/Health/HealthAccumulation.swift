import Foundation

/// Per-sub-stat EWMA half-life constants for HEALTH accumulation (S6b / ADR-002).
///
/// Stage-1 starting hypotheses — explicitly NOT load-bearing; to be calibrated
/// against real on-device data at the Day-13 (2026-06-10) review. Property tests
/// reference these constants rather than literal values, so retuning a half-life
/// does not break the suite.
public enum HealthAccumulation {
    /// Fitness builds — and fades — slowly.
    public static let strengthHalfLifeDays: Double = 14.0
    /// The recovery trend turns faster than fitness.
    public static let fatigueHalfLifeDays: Double = 4.0
    /// Moot until Stage 3 gives HUNGER a real input (its daily input is a constant 50).
    public static let hungerHalfLifeDays: Double = 7.0
}

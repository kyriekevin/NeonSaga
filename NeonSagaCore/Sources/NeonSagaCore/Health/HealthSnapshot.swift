import Foundation

/// Timestamped snapshot of HEALTH sub-stat values derived from raw Apple Health signals.
public struct HealthSnapshot {
    public let capturedAt: Date
    public let metrics: HealthMetrics
    public let hunger: SubStatValue
    public let fatigue: SubStatValue
    public let strength: SubStatValue

    /// HEALTH aggregate value = average of sub-stat values, clamped 0...100.
    public var healthValue: Double {
        HealthStat.value(
            hunger: hunger.value, fatigue: fatigue.value, strength: strength.value)
    }

    /// HEALTH aggregate level = floor(average of sub-stat LVs).
    public var healthLevel: Int {
        HealthStat.level(
            hunger: hunger.value, fatigue: fatigue.value, strength: strength.value)
    }

    /// Pure synchronous mapping from raw metrics to a timestamped snapshot.
    ///
    /// All derived values are guaranteed finite and clamped to 0...100.
    public static func derive(from metrics: HealthMetrics, at capturedAt: Date) -> HealthSnapshot {
        // Normalize each signal to 0...100.
        let normHRV = clamp(sanitize(metrics.hrvRMSSD), 0, 100)
        let normSleep = clamp(sanitize(metrics.sleepEfficiency) * 100, 0, 100)
        let normWk = clamp(sanitize(metrics.activeWorkoutEnergyKilocalories) / 6.0, 0, 100)

        // FATIGUE: conditioning/readiness — strictly increasing in HRV, sleep, and workout.
        let fatigueValue = clamp((normHRV + normSleep + normWk) / 3.0, 0, 100)

        // STRENGTH: depends ONLY on workout energy (PRODUCT §9).
        let strengthValue = clamp(normWk, 0, 100)

        // HUNGER: Stage-1 neutral placeholder (no source until Stage 3).
        let hungerValue = 50.0

        return HealthSnapshot(
            capturedAt: capturedAt,
            metrics: metrics,
            hunger: SubStatValue(.hunger, value: hungerValue),
            fatigue: SubStatValue(.fatigue, value: fatigueValue),
            strength: SubStatValue(.strength, value: strengthValue)
        )
    }
}

// MARK: - Private helpers

/// Returns `x` if finite, otherwise `0`. Must be called before any clamp or
/// arithmetic — Swift's `min`/`max` propagate NaN unpredictably.
private func sanitize(_ x: Double?) -> Double {
    guard let x = x, x.isFinite else { return 0 }
    return x
}

/// Clamps `x` to `[lo, hi]`. Input is assumed finite (call `sanitize` first).
private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
    min(max(x, lo), hi)
}

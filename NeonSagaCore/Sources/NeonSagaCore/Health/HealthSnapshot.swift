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
        // Normalize each raw signal to a 0...100 contribution, or nil if the sample is
        // absent / non-finite. Missing samples are EXCLUDED from averages — never counted
        // as a 0 reading (which would mean "worst state"), so one gap can't crater a stat.
        let normHRV = normalized(metrics.hrvRMSSD) { $0 }
        let normSleep = normalized(metrics.sleepEfficiency) { $0 * 100 }
        let normWk = normalized(metrics.activeWorkoutEnergyKilocalories) { $0 / 6.0 }

        // FATIGUE: conditioning/readiness — mean of the available signals (HRV, sleep,
        // workout), each higher = better; neutral 50 when no signal is available.
        let fatigueInputs = [normHRV, normSleep, normWk].compactMap { $0 }
        let fatigueValue =
            fatigueInputs.isEmpty ? 50.0 : fatigueInputs.reduce(0, +) / Double(fatigueInputs.count)

        // STRENGTH: depends ONLY on workout energy (PRODUCT §9); 0 when no workout sample.
        let strengthValue = normWk ?? 0.0

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

/// Normalizes an optional raw metric to a clamped 0...100 contribution, or `nil` if the
/// sample is absent (`nil`), non-finite (`NaN`/`±inf`), or its transform overflows to
/// non-finite. Guarding `isFinite` on BOTH the raw input and the transformed result is
/// required — `min`/`max` propagate `NaN`, and clamping `±inf` would silently fabricate a
/// bound — so an invalid signal is excluded from averages rather than scored 0 or a bound.
private func normalized(_ raw: Double?, _ transform: (Double) -> Double) -> Double? {
    guard let raw = raw, raw.isFinite else { return nil }
    let transformed = transform(raw)
    guard transformed.isFinite else { return nil }
    return transformed.clamped(to: 0...100)
}

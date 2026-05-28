/// Strain score: monotone, saturating 0–21 exertion score from raw active workout energy.
///
/// Stage-1 constant K = 300 kcal; formula `21 × e / (e + K)` gives `strain(0) = 0`,
/// strictly increasing, concave (diminishing returns), asymptotically bounded below 21.
/// No Foundation / HealthKit / UIKit imports; pure arithmetic only.

// MARK: - Public types

public enum StrainResult: Equatable {
    case noData
    case scored(value: Double)
}

// MARK: - Strain namespace

public enum Strain {
    /// Top of the 0–21 Whoop-convention scale. Stage-1 constant (tunable; tests don't pin it).
    private static let maxStrain = 21.0
    /// Half-saturation energy: kcal at which Strain reaches maxStrain / 2. Stage-1 constant.
    private static let halfSaturationKcal = 300.0

    /// Synchronous Strain score from a single snapshot.
    ///
    /// Reads ONLY `snapshot.metrics.activeWorkoutEnergyKilocalories`.
    /// Does NOT read any other metric or derived sub-stat.
    public static func score(for snapshot: HealthSnapshot) -> StrainResult {
        // 1. Require a finite active-energy value.
        guard let raw = snapshot.metrics.activeWorkoutEnergyKilocalories, raw.isFinite else {
            return .noData
        }

        // 2. Clamp negative finite energy to zero (defensive; a negative kcal is not .noData).
        let e = max(raw, 0.0)

        // 3. Saturating map 21·e/(e+K), written as 21 - 21·K/(e+K): algebraically identical
        //    but never forms 21·e — avoids +inf overflow at huge finite e; stays strictly
        //    < maxStrain for all finite e ≥ 0 (Codex diff-review).
        let computed = maxStrain - maxStrain * halfSaturationKcal / (e + halfSaturationKcal)

        // 4. Defensive clamp to 0...maxStrain (the form above already keeps it in range).
        return .scored(value: clampStrain(computed, 0, maxStrain))
    }
}

// MARK: - Private helpers

/// Clamps `x` to [lo, hi].
private func clampStrain(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
    min(max(x, lo), hi)
}

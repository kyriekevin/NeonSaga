/// Recovery score: baseline-normalised 0–100 readiness from HRV / RHR / sleep.
///
/// Stage-1 constants — weights 0.5 / 0.25 / 0.25, z-scale 15, RHR map over 40…100.
/// No Foundation / HealthKit / UIKit imports; `Double.squareRoot()` is stdlib.

// MARK: - Public types

public enum RecoveryBand: Equatable {
    case red, yellow, green
}

public enum RecoveryResult: Equatable {
    case calibrating(daysOfData: Int)
    case scored(value: Double, band: RecoveryBand)
}

// MARK: - Recovery namespace

public enum Recovery {
    /// Band assignment: value < 34 → .red ; 34 ≤ value < 67 → .yellow ; ≥ 67 → .green.
    public static func band(for value: Double) -> RecoveryBand {
        if value < 34 { return .red }
        if value < 67 { return .yellow }
        return .green
    }

    /// Synchronous recovery score from a single snapshot + multi-day HRV baseline.
    ///
    /// Reads ONLY `snapshot.metrics.hrvRMSSD`, `.restingHeartRate`, `.sleepEfficiency`.
    /// Does NOT read `activeWorkoutEnergyKilocalories` or any derived sub-stat.
    public static func score(
        for snapshot: HealthSnapshot,
        hrvBaseline: [Double]
    ) -> RecoveryResult {
        // 1. Filter baseline to finite entries only.
        let finite = hrvBaseline.filter { $0.isFinite }
        let n = finite.count

        // 2. Calibrating gate — missing/non-finite today-HRV OR < 14 finite baseline samples.
        let todayHRV = snapshot.metrics.hrvRMSSD
        guard let hrv = todayHRV, hrv.isFinite, n >= 14 else {
            return .calibrating(daysOfData: n)
        }

        // 3. HRV term (weight 0.5) — baseline-normalised z-score.
        let mean = finite.reduce(0.0, +) / Double(n)
        let variance = finite.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n)
        let std = variance.squareRoot()

        let hrvTerm: Double
        if std > 0 && std.isFinite {
            let z = (hrv - mean) / std
            hrvTerm = clampVal(50.0 + z * 15.0, 0, 100)
        } else {
            // Zero-variance or non-finite std → neutral; today-HRV must not matter.
            hrvTerm = 50.0
        }

        // 4. Resting-HR term (weight 0.25) — lower is better, mapped over 40…100.
        let rhrTerm: Double
        if let rhr = snapshot.metrics.restingHeartRate, rhr.isFinite {
            rhrTerm = clampVal((100.0 - rhr) / 60.0 * 100.0, 0, 100)
        } else {
            rhrTerm = 50.0
        }

        // 5. Sleep term (weight 0.25) — higher is better; efficiency is a 0…1 fraction.
        let sleepTerm: Double
        if let eff = snapshot.metrics.sleepEfficiency, eff.isFinite {
            sleepTerm = clampVal(eff * 100.0, 0, 100)
        } else {
            sleepTerm = 50.0
        }

        // 6. Weighted blend.
        let value = clampVal(0.5 * hrvTerm + 0.25 * rhrTerm + 0.25 * sleepTerm, 0, 100)
        return .scored(value: value, band: Recovery.band(for: value))
    }
}

// MARK: - Private helpers

/// Clamps `x` to [lo, hi]. Kept private to this file to avoid colliding with
/// the identically-named private helper in HealthSnapshot.swift.
private func clampVal(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
    min(max(x, lo), hi)
}

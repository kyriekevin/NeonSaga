/// Sleep architecture summary: Deep / REM / Light minutes, time-in-bed efficiency,
/// and wake events from a `HealthSnapshot`'s raw sleep-stage fields.
///
/// Mirrors the `Strain`/`Recovery` shape. No Foundation / HealthKit / UIKit imports;
/// pure arithmetic only. The `SleepResult` reads ONLY the five S8 sleep fields —
/// varying RHR / HRV / sleepEfficiency / workout energy never changes the result.

// MARK: - Public types

public enum SleepResult: Equatable {
    case noData
    case scored(SleepSummary)
}

/// Derived architecture summary for a single night.
///
/// Equatable is synthesized over the STORED properties only — computed properties
/// (asleepMinutes, fractions, efficiency) are excluded so presence-invariance equality
/// holds without requiring them in the synthesized conformance.
public struct SleepSummary: Equatable {
    // MARK: Stored
    public let deepMinutes: Double
    public let remMinutes: Double
    public let lightMinutes: Double
    /// Raw time-in-bed: present when the source value is finite and > 0, else `nil`.
    public let timeInBedMinutes: Double?
    /// Wake events: present when the source count is non-nil and ≥ 0, else `nil`.
    public let wakeEvents: Int?

    // MARK: Computed
    /// Total minutes asleep (deep + rem + light). Always > 0 for a scored summary.
    public var asleepMinutes: Double { deepMinutes + remMinutes + lightMinutes }
    /// Fraction of asleep time in deep stage (`deepMinutes / asleepMinutes`).
    public var deepFraction: Double { deepMinutes / asleepMinutes }
    /// Fraction of asleep time in REM stage (`remMinutes / asleepMinutes`).
    public var remFraction: Double { remMinutes / asleepMinutes }
    /// Fraction of asleep time in light stage (`lightMinutes / asleepMinutes`).
    public var lightFraction: Double { lightMinutes / asleepMinutes }
    /// Sleep efficiency: `min(asleepMinutes / timeInBedMinutes, 1.0)`, or `nil` when
    /// `timeInBedMinutes` is absent. Clamped at 1.0 for noisy data where asleep > in-bed.
    public var efficiency: Double? {
        guard let bed = timeInBedMinutes else { return nil }
        return (asleepMinutes / bed).clamped(to: 0...1)
    }
}

// MARK: - Sleep namespace

public enum Sleep {
    /// Derives a `SleepResult` from the raw sleep-stage signals on `snapshot`.
    ///
    /// Reads ONLY the five sleep fields on `snapshot.metrics`. Varying RHR / HRV /
    /// sleepEfficiency / workout energy never changes the result (presence-invariance).
    public static func summary(for snapshot: HealthSnapshot) -> SleepResult {
        let m = snapshot.metrics

        // Sanitise each stage: non-finite or negative → 0.
        let deep = sanitise(m.deepSleepMinutes)
        let rem = sanitise(m.remSleepMinutes)
        let light = sanitise(m.lightSleepMinutes)

        let asleep = deep + rem + light

        // noData gate: zero / non-positive asleep, or post-sum overflow to non-finite.
        guard asleep.isFinite && asleep > 0 else { return .noData }

        // time-in-bed: only when finite and strictly > 0.
        let bedRaw = m.timeInBedMinutes
        let bed: Double?
        if let b = bedRaw, b.isFinite && b > 0 {
            bed = b
        } else {
            bed = nil
        }

        // wake events: only when non-nil and >= 0.
        let wake: Int?
        if let w = m.wakeEventsCount, w >= 0 {
            wake = w
        } else {
            wake = nil
        }

        let summary = SleepSummary(
            deepMinutes: deep,
            remMinutes: rem,
            lightMinutes: light,
            timeInBedMinutes: bed,
            wakeEvents: wake)
        return .scored(summary)
    }

    // MARK: - Private

    /// Sanitises a raw stage value: non-finite or negative → 0.
    private static func sanitise(_ raw: Double?) -> Double {
        guard let v = raw, v.isFinite, v >= 0 else { return 0 }
        return v
    }
}

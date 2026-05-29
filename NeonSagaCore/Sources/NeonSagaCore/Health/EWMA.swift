import Foundation

/// Time-aware exponential accumulation primitive for HEALTH sub-stats
/// (S6b / ADR-002 Decision 2). Pure core — no SwiftData / HealthKit.
///
/// `accumulated = retentionᐞ · previous + (1 − retentionᐞ) · dailyInput`, where
/// `retentionᐞ = 0.5^(elapsedDays / halfLifeDays)`. Because retention is raised
/// to the elapsed time, a multi-day gap decays by the FULL elapsed time, not a
/// single step. Cold start (no previous record) is the store's concern — it
/// seeds `accumulated = dailyInput` directly, not via this primitive.
public enum EWMA {
    /// - `elapsedDays` < 0 is clamped to 0 (no negative decay).
    /// - `halfLifeDays` must be > 0.
    /// - For 0...100 `previous`/`dailyInput`, the result stays within
    ///   `[min, max]` of the two — hence finite and in 0...100.
    public static func accumulate(
        previous: Double, dailyInput: Double, elapsedDays: Double, halfLifeDays: Double
    ) -> Double {
        // S6b RED stub — GREEN implements the time-aware formula (retention^Δt,
        // negative-Δt clamp, finite guards). The sentinel fails the assertions so
        // `make test-core` stays red until the real body lands.
        0
    }
}

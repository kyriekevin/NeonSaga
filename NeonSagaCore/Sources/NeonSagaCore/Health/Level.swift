/// Per-value LV math — PRODUCT §7.
///
/// Formula: `floor((value / 100) × 99) + 1`, clamped to 1–100.
public enum Level {
    /// Returns the LV for a raw sub-stat value.
    ///
    /// - Negative values clamp to LV 1.
    /// - Values above 100 clamp to LV 100.
    public static func of(_ value: Double) -> Int {
        let raw = (value / 100.0 * 99.0).rounded(.down) + 1.0
        return Int(min(max(raw, 1.0), 100.0))
    }
}

/// A sub-stat value paired with its `SubStat` identity.
///
/// `level` is always derived from the stored `value` — no duplication.
public struct SubStatValue {
    public let substat: SubStat
    public let value: Double

    public init(_ substat: SubStat, value: Double) {
        self.substat = substat
        self.value = value
    }

    /// The computed LV for this sub-stat value (PRODUCT §7).
    public var level: Int { Level.of(value) }
}

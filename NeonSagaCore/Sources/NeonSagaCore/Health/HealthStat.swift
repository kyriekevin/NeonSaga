/// Top-level HEALTH stat aggregation (PRODUCT §6/§7).
public enum HealthStat {
    /// HEALTH value = average of raw sub-stat values, clamped to 0–100.
    public static func value(hunger: Double, fatigue: Double, strength: Double) -> Double {
        let avg = (hunger + fatigue + strength) / 3.0
        return min(max(avg, 0.0), 100.0)
    }

    /// HEALTH LV = `floor` of the average of the three sub-stat LVs.
    ///
    /// This is NOT `Level.of(average of raw values)` — each sub-stat LV is
    /// computed independently first, then averaged (PRODUCT §7). Integer
    /// division floors here because the LV sum is always positive (each LV ≥ 1).
    public static func level(hunger: Double, fatigue: Double, strength: Double) -> Int {
        let hungerLv = Level.of(hunger)
        let fatigueLv = Level.of(fatigue)
        let strengthLv = Level.of(strength)
        return (hungerLv + fatigueLv + strengthLv) / 3
    }
}

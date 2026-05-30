/// Records a level-up crossing from `oldLevel` to `newLevel`.
public struct LevelCrossing: Hashable {
    public let oldLevel: Int
    public let newLevel: Int

    public init(oldLevel: Int, newLevel: Int) {
        self.oldLevel = oldLevel
        self.newLevel = newLevel
    }
}

/// Level-up crossing detection.
public enum LevelUp {
    /// Returns a `LevelCrossing` iff the new value's LV strictly exceeds the old value's LV.
    ///
    /// Returns `nil` for equal or decreasing LVs, and for value changes that do not cross
    /// a LV boundary.
    public static func detect(from oldValue: Double, to newValue: Double) -> LevelCrossing? {
        let oldLv = Level.of(oldValue)
        let newLv = Level.of(newValue)
        guard newLv > oldLv else { return nil }
        return LevelCrossing(oldLevel: oldLv, newLevel: newLv)
    }
}

/// A level-up crossing on a specific HEALTH sub-stat. `Hashable` so the takeover view
/// can use the crossing as a SwiftUI `.id(...)` to re-fire its intro per queued crossing.
public struct SubStatLevelCrossing: Hashable {
    public let substat: SubStat
    public let crossing: LevelCrossing

    public init(substat: SubStat, crossing: LevelCrossing) {
        self.substat = substat
        self.crossing = crossing
    }
}

extension LevelUp {
    /// One crossing per HEALTH sub-stat whose LV strictly increased old -> new, in the
    /// fixed order hunger -> fatigue -> strength. Non-crossings omitted; delegates per
    /// sub-stat to `LevelUp.detect`.
    public static func detectCrossings(
        from old: (hunger: Double, fatigue: Double, strength: Double),
        to new: (hunger: Double, fatigue: Double, strength: Double)
    ) -> [SubStatLevelCrossing] {
        var out: [SubStatLevelCrossing] = []
        if let c = detect(from: old.hunger, to: new.hunger) {
            out.append(SubStatLevelCrossing(substat: .hunger, crossing: c))
        }
        if let c = detect(from: old.fatigue, to: new.fatigue) {
            out.append(SubStatLevelCrossing(substat: .fatigue, crossing: c))
        }
        if let c = detect(from: old.strength, to: new.strength) {
            out.append(SubStatLevelCrossing(substat: .strength, crossing: c))
        }
        return out
    }
}

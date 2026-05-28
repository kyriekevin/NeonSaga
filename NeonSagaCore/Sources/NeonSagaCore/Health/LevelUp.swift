/// Records a level-up crossing from `oldLevel` to `newLevel`.
public struct LevelCrossing: Equatable {
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

extension Comparable {
    /// Returns `self` clamped into `range` (`min(max(self, lower), upper)`).
    ///
    /// `range` must be non-inverted (`lowerBound <= upperBound`); every call site
    /// passes a finite value and a small fixed range (e.g. `0...100`, `0...21`).
    /// Behaviorally identical to the per-file `min(max(...))` clamp helpers this replaces.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

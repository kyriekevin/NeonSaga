/// NeonSagaCore — pure Swift core for the NeonSaga RPG character sheet.
///
/// No SwiftUI / SwiftData / UIKit / HealthKit / CoreLocation here (CLAUDE.md
/// §3). Algorithms, protocols, enums, and AI-service stubs live in this layer
/// so they stay testable on the Command Line Tools alone via the custom runner
/// in `NeonSagaCoreTests` (CLAUDE.md §4).
public enum NeonSagaCore {
    /// Genesis seed marker. Real surface area lands per the Stage 1 CONTRACT.
    public static let version = "0.0.0-genesis"
}

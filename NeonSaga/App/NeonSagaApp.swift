import NeonSagaCore
import SwiftUI

// Genesis app shell — a minimal `@main` so the iOS target builds and
// `make verify-full` is green. The real RootView + 5-tab IA
// (CORE / INGEST / ORACLE / CONTRACTS / ARCHIVE) lands per the Stage 1
// CONTRACT. Genesis bootstrap scaffolding, exempt from red/green (CLAUDE.md
// §1.2). The `NeonSagaCore.version` reference proves the package dependency
// links end-to-end (app → NeonSagaCore).
@main
struct NeonSagaApp: App {
    var body: some Scene {
        WindowGroup {
            GenesisRootView()
        }
    }
}

private struct GenesisRootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("NeonSaga")
                .font(.largeTitle.weight(.bold))
            Text("core \(NeonSagaCore.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

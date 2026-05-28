import NeonSagaCore
import SwiftData
import SwiftUI

// Genesis app shell — a minimal `@main` so the iOS target builds and
// `make verify-full` is green. The real RootView + 5-tab IA
// (CORE / INGEST / ORACLE / CONTRACTS / ARCHIVE) lands per the Stage 1
// CONTRACT. Genesis bootstrap scaffolding, exempt from red/green (CLAUDE.md
// §1.2). The `NeonSagaCore.version` reference proves the package dependency
// links end-to-end (app → NeonSagaCore).
@main
struct NeonSagaApp: App {
    // CloudKit stays dormant (`cloudKitDatabase: .none`) until a paid Apple
    // Developer account. The explicit configuration prevents SwiftData from
    // auto-enabling sync once a CloudKit entitlement is added (CLAUDE.md §5);
    // the convenience `.modelContainer(for:)` would default to `.automatic`.
    let modelContainer: ModelContainer

    init() {
        do {
            let configuration = ModelConfiguration(cloudKitDatabase: .none)
            modelContainer = try ModelContainer(
                for: HealthSnapshotRecord.self, configurations: configuration)
        } catch {
            fatalError("Failed to build the NeonSaga ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            GenesisRootView()
        }
        .modelContainer(modelContainer)
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

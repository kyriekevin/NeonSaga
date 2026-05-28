import SwiftData
import SwiftUI

// S6: HealthDetailView is the temporary app root while the 5-tab IA is unbuilt.
// This is NOT the permanent PRODUCT §9 CORE first-eye character sheet; it is an
// installable entry point so the HEALTH detail surface is reachable and inspectable.
// Once CORE/RootView lands, HEALTH detail becomes a drill-down from CORE.
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
            HealthDetailView()
        }
        .modelContainer(modelContainer)
    }
}

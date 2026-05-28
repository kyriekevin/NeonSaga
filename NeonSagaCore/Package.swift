// swift-tools-version: 6.0
import PackageDescription

// NeonSagaCore — pure Swift core (no SwiftUI / SwiftData / UIKit / HealthKit /
// CoreLocation). See CLAUDE.md §3 for the two-layer split and §4 for why the
// test target is an `.executableTarget` custom runner rather than XCTest.
let package = Package(
    name: "NeonSagaCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NeonSagaCore", targets: ["NeonSagaCore"])
    ],
    targets: [
        .target(name: "NeonSagaCore"),
        .executableTarget(
            name: "NeonSagaCoreTests",
            dependencies: ["NeonSagaCore"]
        ),
    ]
)

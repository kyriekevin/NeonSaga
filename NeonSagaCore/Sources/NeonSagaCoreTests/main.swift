import Foundation
import NeonSagaCore

// MARK: - Custom test runner
//
// `NeonSagaCoreTests` is an `.executableTarget`, NOT XCTest. Apple's CLT ships
// an incomplete XCTest/Testing stack (missing `lib_TestingInterop.dylib`), so
// `swift test` cannot host this layer (CLAUDE.md §4). This runner uses
// top-level code (which is `@MainActor`-isolated) + `@MainActor` helpers, and
// exits non-zero on the first failed expectation. To narrow scope while
// debugging, comment out unrelated `group(...)` calls.

@MainActor
private enum Runner {
    static var passCount = 0
    static var currentGroup = "<root>"
}

@MainActor
func group(_ name: String, _ body: () -> Void) {
    Runner.currentGroup = name
    body()
}

@MainActor
func group(_ name: String, _ body: () async -> Void) async {
    Runner.currentGroup = name
    await body()
}

@MainActor
func expect(
    _ condition: Bool,
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    if condition {
        Runner.passCount += 1
    } else {
        print("❌ FAIL [\(Runner.currentGroup)] \(message)  (\(file):\(line))")
        print("   \(Runner.passCount) passed before this failure")
        exit(1)
    }
}

@MainActor
func expectAsync(
    _ condition: @autoclosure () async -> Bool,
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
) async {
    let value = await condition()
    expect(value, message, file: file, line: line)
}

// MARK: - Test groups
//
// Genesis smoke test only — proves the runner links `NeonSagaCore` and the
// expect/exit mechanism works. Real groups (HealthSnapshot.derive, Recovery
// math, cross-domain rules, …) land per the Stage 1 CONTRACT.

group("genesis-smoke") {
    expect(NeonSagaCore.version == "0.0.0-genesis", "NeonSagaCore.version seed reachable")
    expect(1 + 1 == 2, "runner arithmetic sanity")
}

// MARK: - Summary
//
// Fail-fast above means reaching here implies every expectation passed.
print("✅ \(Runner.passCount) passed, 0 failed")

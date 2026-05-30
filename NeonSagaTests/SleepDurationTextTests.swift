import XCTest

@testable import NeonSaga

/// S8 diff-review fix (Codex 2b finding 1): the Sleep card's minutes→"Xh Ym" formatter
/// was duplicated across two private view helpers and cast `Int(Double)` unguarded — a
/// contract-valid but pathological finite Double > Int.max would trap. These pin the
/// single shared `sleepDurationText(_:)` helper: correct formatting + a finite/range
/// guard returning an em-dash instead of trapping.
final class SleepDurationTextTests: XCTestCase {

    func testFormatsHoursAndMinutes() {
        XCTAssertEqual(sleepDurationText(390), "6h 30m")
        XCTAssertEqual(sleepDurationText(60), "1h 0m")
        XCTAssertEqual(sleepDurationText(45), "45m")
        XCTAssertEqual(sleepDurationText(0), "0m")
    }

    func testGuardsNonFiniteAndOutOfRange() {
        XCTAssertEqual(sleepDurationText(.infinity), "—")
        XCTAssertEqual(sleepDurationText(.nan), "—")
        XCTAssertEqual(sleepDurationText(-5), "—")
        XCTAssertEqual(sleepDurationText(Double(Int.max)), "—")
    }
}

import XCTest
@testable import Blankie

final class SleepTimerTests: XCTestCase {
    func testFormatDisplayStringForMinutesAndSeconds() {
        XCTAssertEqual(SleepTimer.formatDisplayString(fromSeconds: 90), "1:30")
        XCTAssertEqual(SleepTimer.formatDisplayString(fromSeconds: 5), "0:05")
    }

    func testFormatDisplayStringForHours() {
        XCTAssertEqual(SleepTimer.formatDisplayString(fromSeconds: 3661), "1:01:01")
    }

    func testFormatDisplayStringForNonPositiveValues() {
        XCTAssertEqual(SleepTimer.formatDisplayString(fromSeconds: 0), "")
        XCTAssertEqual(SleepTimer.formatDisplayString(fromSeconds: -1), "")
    }

    func testClampedSeconds() {
        XCTAssertEqual(SleepTimer.clampedSeconds(0), 60)
        XCTAssertEqual(SleepTimer.clampedSeconds(59), 60)
        XCTAssertEqual(SleepTimer.clampedSeconds(60), 60)
        XCTAssertEqual(SleepTimer.clampedSeconds(125.2), 125)
    }
}

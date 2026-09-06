import XCTest
@testable import RadioAtlasCore

final class SleepTimerTests: XCTestCase {
    func testScheduledTimerFiresOnExpiry() async {
        let fired = expectation(description: "sleep timer fired")
        let timer = SleepTimer()

        timer.schedule(seconds: 0.05) { fired.fulfill() }

        XCTAssertTrue(timer.isActive)
        XCTAssertNotNil(timer.fireDate)
        await fulfillment(of: [fired], timeout: 2)
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.fireDate)
    }

    func testCancelPreventsExpiry() async {
        let timer = SleepTimer()
        var didFire = false
        timer.schedule(seconds: 0.05) { didFire = true }

        timer.cancel()

        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.fireDate)
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertFalse(didFire)
    }

    func testReschedulingReplacesThePreviousTimer() async {
        let secondFired = expectation(description: "second schedule fired")
        let timer = SleepTimer()
        var firstDidFire = false
        timer.schedule(seconds: 0.03) { firstDidFire = true }
        timer.schedule(seconds: 0.05) { secondFired.fulfill() }

        await fulfillment(of: [secondFired], timeout: 2)

        XCTAssertFalse(firstDidFire)
    }
}

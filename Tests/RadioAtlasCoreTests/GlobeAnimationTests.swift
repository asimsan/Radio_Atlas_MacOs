import XCTest
@testable import RadioAtlasCore

final class GlobeAnimationTests: XCTestCase {
    // MARK: - longitudeDelta

    func testLongitudeDeltaIsDirectDifferenceWhenNoWrap() {
        XCTAssertEqual(GlobeAnimation.longitudeDelta(from: 10, to: 30), 20, accuracy: 0.0001)
        XCTAssertEqual(GlobeAnimation.longitudeDelta(from: 30, to: -10), -40, accuracy: 0.0001)
    }

    func testLongitudeDeltaTakesShortestArcAcrossDateline() {
        // 170°E -> 170°W is +20°, not -340°.
        XCTAssertEqual(GlobeAnimation.longitudeDelta(from: 170, to: -170), 20, accuracy: 0.0001)
        // And the reverse direction is -20°.
        XCTAssertEqual(GlobeAnimation.longitudeDelta(from: -170, to: 170), -20, accuracy: 0.0001)
        // 350°E to 0° is +10° east, not -350°.
        XCTAssertEqual(GlobeAnimation.longitudeDelta(from: 350, to: 0), 10, accuracy: 0.0001)
    }

    func testLongitudeDeltaIsZeroForSamePoint() {
        XCTAssertEqual(GlobeAnimation.longitudeDelta(from: 30, to: 30), 0, accuracy: 0.0001)
    }

    // MARK: - easeInOut

    func testEaseInOutHitsEndpoints() {
        XCTAssertEqual(GlobeAnimation.easeInOut(0), 0, accuracy: 0.0001)
        XCTAssertEqual(GlobeAnimation.easeInOut(1), 1, accuracy: 0.0001)
    }

    func testEaseInOutPassesThroughHalfwayPoint() {
        XCTAssertEqual(GlobeAnimation.easeInOut(0.5), 0.5, accuracy: 0.0001)
    }

    func testEaseInOutIsSymmetric() {
        // Ease-in-out curves are symmetric: p(t) + p(1-t) == 1.
        XCTAssertEqual(
            GlobeAnimation.easeInOut(0.25) + GlobeAnimation.easeInOut(0.75),
            1,
            accuracy: 0.0001
        )
    }

    func testEaseInOutClampsOutOfRangeInput() {
        XCTAssertEqual(GlobeAnimation.easeInOut(-0.5), 0, accuracy: 0.0001)
        XCTAssertEqual(GlobeAnimation.easeInOut(1.5), 1, accuracy: 0.0001)
    }
}

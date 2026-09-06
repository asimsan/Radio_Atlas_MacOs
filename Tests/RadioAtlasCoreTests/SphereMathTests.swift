import XCTest
@testable import RadioAtlasCore

final class SphereMathTests: XCTestCase {
    func testEquatorPrimeMeridianIsOnPositiveXAxis() {
        let p = SphereMath.point(radius: 1.0, latitude: 0, longitude: 0)
        XCTAssertEqual(p.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(p.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(p.z, 0.0, accuracy: 0.0001)
    }

    func testNorthPoleIsOnPositiveYAxis() {
        let p = SphereMath.point(radius: 2.0, latitude: 90, longitude: 0)
        XCTAssertEqual(p.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(p.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(p.z, 0.0, accuracy: 0.0001)
    }
}

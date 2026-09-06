import XCTest
@testable import RadioAtlasCore

final class GlobeProjectionTests: XCTestCase {
    func testCenterPointProjectsToOriginAndIsFrontFacing() {
        let result = GlobeProjection.project(
            GeoPoint(latitude: 10, longitude: 20),
            centerLatitude: 10, centerLongitude: 20, scale: 1, viewRadius: 100
        )
        XCTAssertEqual(result.point.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.point.y, 0, accuracy: 0.001)
        XCTAssertTrue(result.isFrontFacing)
    }

    func testAntipodalPointIsNotFrontFacing() {
        let result = GlobeProjection.project(
            GeoPoint(latitude: -10, longitude: -160),
            centerLatitude: 10, centerLongitude: 20, scale: 1, viewRadius: 100
        )
        XCTAssertFalse(result.isFrontFacing)
    }

    func testProjectUnprojectRoundTripsNearCenter() throws {
        let original = GeoPoint(latitude: 15, longitude: 25)
        let projected = GlobeProjection.project(
            original, centerLatitude: 10, centerLongitude: 20, scale: 1, viewRadius: 100
        )
        XCTAssertTrue(projected.isFrontFacing)
        let recovered = try XCTUnwrap(GlobeProjection.unproject(
            projected.point, centerLatitude: 10, centerLongitude: 20, scale: 1, viewRadius: 100
        ))
        XCTAssertEqual(recovered.latitude, original.latitude, accuracy: 0.01)
        XCTAssertEqual(recovered.longitude, original.longitude, accuracy: 0.01)
    }

    func testUnprojectReturnsNilOutsideSphereSilhouette() {
        let result = GlobeProjection.unproject(
            CGPoint(x: 500, y: 500), centerLatitude: 0, centerLongitude: 0, scale: 1, viewRadius: 100
        )
        XCTAssertNil(result)
    }
}

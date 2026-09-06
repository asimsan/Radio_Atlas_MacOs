import XCTest
@testable import RadioAtlasCore

final class RegionCentroidTests: XCTestCase {
    func testSquarePolygonCentersOnItsMiddle() throws {
        // 10°×10° square: latitude 0–10, longitude 0–10.
        let region = CountryRegion(isoCode: "SQ", rings: [[
            GeoPoint(latitude: 0, longitude: 0),
            GeoPoint(latitude: 0, longitude: 10),
            GeoPoint(latitude: 10, longitude: 10),
            GeoPoint(latitude: 10, longitude: 0),
            GeoPoint(latitude: 0, longitude: 0),
        ]])

        let centroid = try XCTUnwrap(RegionCentroid.centroid(of: region))

        XCTAssertEqual(centroid.latitude, 5, accuracy: 0.001)
        XCTAssertEqual(centroid.longitude, 5, accuracy: 0.001)
    }

    func testDatelineCrossingPolygonCentersAt180Degrees() throws {
        // Same square, but shifted so it straddles the ±180° dateline.
        let region = CountryRegion(isoCode: "DL", rings: [[
            GeoPoint(latitude: 0, longitude: 175),
            GeoPoint(latitude: 0, longitude: -175),
            GeoPoint(latitude: 10, longitude: -175),
            GeoPoint(latitude: 10, longitude: 175),
            GeoPoint(latitude: 0, longitude: 175),
        ]])

        let centroid = try XCTUnwrap(RegionCentroid.centroid(of: region))

        XCTAssertEqual(centroid.latitude, 5, accuracy: 0.001)
        XCTAssertEqual(abs(centroid.longitude), 180, accuracy: 0.001)
    }

    func testMultiRingCentroidIsAreaWeightedTowardLargerRing() throws {
        // 10°×10° mainland plus a tiny 1°×1° island.
        let region = CountryRegion(isoCode: "MR", rings: [
            [
                GeoPoint(latitude: 0, longitude: 0),
                GeoPoint(latitude: 0, longitude: 10),
                GeoPoint(latitude: 10, longitude: 10),
                GeoPoint(latitude: 10, longitude: 0),
                GeoPoint(latitude: 0, longitude: 0),
            ],
            [
                GeoPoint(latitude: 20, longitude: 20),
                GeoPoint(latitude: 20, longitude: 21),
                GeoPoint(latitude: 21, longitude: 21),
                GeoPoint(latitude: 21, longitude: 20),
                GeoPoint(latitude: 20, longitude: 20),
            ],
        ])

        let centroid = try XCTUnwrap(RegionCentroid.centroid(of: region))

        // Weighted: (100·5 + 1·20.5) / 101 ≈ 5.15 — the island nudges it.
        XCTAssertEqual(centroid.latitude, 5.15, accuracy: 0.1)
        XCTAssertEqual(centroid.longitude, 5.15, accuracy: 0.1)
    }

    func testEmptyRingsReturnNil() {
        XCTAssertNil(RegionCentroid.centroid(of: CountryRegion(isoCode: "EM", rings: [])))
    }

    func testDegenerateRingsReturnNil() {
        let region = CountryRegion(isoCode: "DG", rings: [[
            GeoPoint(latitude: 0, longitude: 0),
            GeoPoint(latitude: 1, longitude: 1),
        ]])
        XCTAssertNil(RegionCentroid.centroid(of: region))
    }
}

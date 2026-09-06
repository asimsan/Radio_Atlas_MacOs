import XCTest
@testable import RadioAtlasCore

final class OvationAuroraDataTests: XCTestCase {
    func testDecodesCoordinateTriples() throws {
        let json = """
        {"Observation Time": "2026-09-06T21:35:00Z",
         "Forecast Time": "2026-09-06T22:50:00Z",
         "Data Format": "[Longitude, Latitude, Aurora]",
         "coordinates": [[0, -90, 4], [0, -89, 0], [1, 60, 12.5]]}
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(OvationAuroraData.self, from: json)

        XCTAssertEqual(data.coordinates.count, 3)
        XCTAssertEqual(data.coordinates[0], OvationPoint(longitude: 0, latitude: -90, aurora: 4))
        XCTAssertEqual(data.coordinates[2], OvationPoint(longitude: 1, latitude: 60, aurora: 12.5))
    }

    func testDropsMalformedTriplesInsteadOfFailingTheWholeFeed() throws {
        let json = """
        {"coordinates": [[0, -90, 4], [1, 2], [3, 40, 7]]}
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(OvationAuroraData.self, from: json)

        XCTAssertEqual(data.coordinates.count, 2)
        XCTAssertEqual(data.coordinates.map(\.aurora), [4, 7])
    }
}

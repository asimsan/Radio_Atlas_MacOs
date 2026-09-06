import XCTest
@testable import RadioAtlasCore

final class StationTests: XCTestCase {
    private let sampleJSON = """
    {
        "stationuuid": "abc-123",
        "name": "Test FM",
        "url_resolved": "https://stream.example.com/test.mp3",
        "homepage": "https://example.com",
        "favicon": "https://example.com/icon.png",
        "tags": "jazz, live, 24/7",
        "countrycode": "FR",
        "country": "France",
        "geo_lat": 48.85,
        "geo_long": 2.35,
        "votes": 42,
        "clickcount": 1000,
        "bitrate": 128
    }
    """.data(using: .utf8)!

    func testDecodesRawStationAndMapsToStation() throws {
        let raw = try JSONDecoder().decode(RawStation.self, from: sampleJSON)
        let station = try XCTUnwrap(Station(raw: raw))

        XCTAssertEqual(station.id, "abc-123")
        XCTAssertEqual(station.name, "Test FM")
        XCTAssertEqual(station.streamURL, URL(string: "https://stream.example.com/test.mp3"))
        XCTAssertEqual(station.tags, ["jazz", "live", "24/7"])
        XCTAssertEqual(station.countryCode, "FR")
        XCTAssertEqual(station.latitude, 48.85)
        XCTAssertEqual(station.bitrateKbps, 128)
    }

    func testRejectsStationWithMissingStreamURL() throws {
        let json = """
        {"stationuuid": "x", "name": "No Stream", "url_resolved": "",
         "homepage": null, "favicon": "", "tags": "", "countrycode": "US",
         "country": "United States", "geo_lat": null, "geo_long": null,
         "votes": 0, "clickcount": 0, "bitrate": 0}
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawStation.self, from: json)
        XCTAssertNil(Station(raw: raw))
    }
}

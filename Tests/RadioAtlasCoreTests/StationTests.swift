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

    private func json(urlResolved: String, url: String?) -> Data {
        let urlField = url.map { ", \"url\": \"\($0)\"" } ?? ""
        return """
        {
            "stationuuid": "abc-123", "name": "Test FM",
            "url_resolved": "\(urlResolved)"\(urlField),
            "homepage": null, "favicon": "", "tags": "", "countrycode": "NP",
            "country": "Nepal", "geo_lat": null, "geo_long": null,
            "votes": 0, "clickcount": 6, "bitrate": 0
        }
        """.data(using: .utf8)!
    }

    /// Radio Browser leaves `url_resolved` empty until its own resolver has
    /// followed the station's URL, while `url` still works. Butwal FM in Nepal
    /// is one such station, and dropping it lost it from the app entirely.
    func testFallsBackToUrlWhenResolvedURLIsEmpty() throws {
        let raw = try JSONDecoder().decode(
            RawStation.self,
            from: json(urlResolved: "", url: "http://streaming.softnep.net:10994/;stream.nsv")
        )
        let station = try XCTUnwrap(Station(raw: raw))
        XCTAssertEqual(station.streamURL.absoluteString, "http://streaming.softnep.net:10994/;stream.nsv")
    }

    func testPrefersResolvedURLWhenBothArePresent() throws {
        let raw = try JSONDecoder().decode(
            RawStation.self,
            from: json(urlResolved: "https://resolved.example/s", url: "https://raw.example/s")
        )
        let station = try XCTUnwrap(Station(raw: raw))
        XCTAssertEqual(station.streamURL.absoluteString, "https://resolved.example/s")
    }

    func testReturnsNilWhenNeitherURLIsUsable() throws {
        let raw = try JSONDecoder().decode(RawStation.self, from: json(urlResolved: "", url: ""))
        XCTAssertNil(Station(raw: raw))
    }

    /// `url` is absent from older cached payloads, so decoding must not require it.
    func testDecodesWhenUrlFieldIsAbsentEntirely() throws {
        let raw = try JSONDecoder().decode(
            RawStation.self, from: json(urlResolved: "https://only.example/s", url: nil)
        )
        XCTAssertNotNil(Station(raw: raw))
    }

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

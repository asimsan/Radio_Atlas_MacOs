import XCTest
@testable import RadioAtlasCore

final class RadioBrowserClientTests: XCTestCase {
    private let stationsJSON = """
    [{"stationuuid": "a1", "name": "Alpha", "url_resolved": "https://s.example/a.mp3",
      "homepage": null, "favicon": "", "tags": "pop", "countrycode": "US",
      "country": "United States", "geo_lat": 40.0, "geo_long": -74.0,
      "votes": 5, "clickcount": 10, "bitrate": 128}]
    """.data(using: .utf8)!

    func testSearchStationsDecodesResultsAndBuildsQuery() async throws {
        StubURLProtocol.responseData = stationsJSON
        let client = RadioBrowserClient(
            session: StubURLProtocol.makeSession(),
            baseURL: URL(string: "https://radio.test")!
        )

        let stations = try await client.searchStations(query: "alpha")

        XCTAssertEqual(stations.map(\.name), ["Alpha"])
        let requestedURL = try XCTUnwrap(StubURLProtocol.lastRequest?.url)
        XCTAssertEqual(requestedURL.path, "/json/stations/search")
        XCTAssertTrue(requestedURL.query?.contains("name=alpha") ?? false)
    }

    func testStationsByCountryCodeHitsExpectedPath() async throws {
        StubURLProtocol.responseData = stationsJSON
        let client = RadioBrowserClient(
            session: StubURLProtocol.makeSession(),
            baseURL: URL(string: "https://radio.test")!
        )

        _ = try await client.stationsByCountryCode("US")

        let requestedURL = try XCTUnwrap(StubURLProtocol.lastRequest?.url)
        XCTAssertEqual(requestedURL.path, "/json/stations/bycountrycodeexact/US")
    }
}

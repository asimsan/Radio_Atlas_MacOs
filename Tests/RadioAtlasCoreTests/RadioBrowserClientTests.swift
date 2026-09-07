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

    func testTopStationsRequestsTheConfiguredDepthOrderedByPopularity() async throws {
        StubURLProtocol.responseData = stationsJSON
        let client = RadioBrowserClient(
            session: StubURLProtocol.makeSession(),
            baseURL: URL(string: "https://radio.test")!
        )

        _ = try await client.topStations()

        let requestedURL = try XCTUnwrap(StubURLProtocol.lastRequest?.url)
        let query = requestedURL.query ?? ""
        XCTAssertEqual(requestedURL.path, "/json/stations")
        XCTAssertTrue(query.contains("order=clickcount"), query)
        XCTAssertTrue(query.contains("reverse=true"), query)
        // Pinned: the limit drives globe density and country coverage, so a
        // silent change to it is a visible product change.
        XCTAssertTrue(query.contains("limit=\(RadioBrowserClient.defaultTopStationsLimit)"), query)
    }

    /// Radio Browser is a free community service and its API guidance asks
    /// clients to identify themselves; the default URLSession agent does not.
    func testRequestsIdentifyTheAppViaUserAgent() async throws {
        StubURLProtocol.responseData = stationsJSON
        let client = RadioBrowserClient(
            session: StubURLProtocol.makeSession(),
            baseURL: URL(string: "https://radio.test")!
        )

        _ = try await client.topStations()

        let agent = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "User-Agent")
        XCTAssertEqual(agent, RadioBrowserClient.userAgent)
        XCTAssertTrue(agent?.hasPrefix("RadioAtlas/") ?? false, String(describing: agent))
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
        // Country lists should be ordered by popularity so the sidebar shows
        // the same clickcount ordering the world list uses.
        XCTAssertTrue(requestedURL.query?.contains("order=clickcount") ?? false)
        XCTAssertTrue(requestedURL.query?.contains("reverse=true") ?? false)
    }
}

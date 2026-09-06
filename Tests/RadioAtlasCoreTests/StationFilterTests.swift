import XCTest
@testable import RadioAtlasCore

final class StationFilterTests: XCTestCase {
    private func station(
        _ name: String,
        countryCode: String = "US",
        country: String = "United States",
        tags: [String] = []
    ) -> Station {
        Station(id: name, name: name, streamURL: URL(string: "https://s.example/\(name).mp3")!,
                homepage: nil, faviconURL: nil, tags: tags, countryCode: countryCode, country: country,
                latitude: nil, longitude: nil, votes: 0, clickCount: 0, bitrateKbps: 128)
    }

    func testEmptyQueryReturnsAllStations() {
        let stations = [station("Jazz FM"), station("Rock Radio")]
        XCTAssertEqual(StationFilter.filter(stations, query: ""), stations)
    }

    func testFilterIsCaseInsensitiveSubstringMatch() {
        let stations = [station("Jazz FM"), station("Rock Radio")]
        XCTAssertEqual(StationFilter.filter(stations, query: "jazz").map(\.name), ["Jazz FM"])
    }

    func testFilterMatchesCountryName() {
        let stations = [
            station("Jazz FM", countryCode: "US", country: "United States"),
            station("Radio Berlin", countryCode: "DE", country: "Germany")
        ]
        XCTAssertEqual(StationFilter.filter(stations, query: "germany").map(\.name), ["Radio Berlin"])
    }

    func testFilterMatchesCountryCode() {
        let stations = [
            station("Jazz FM", countryCode: "US", country: "United States"),
            station("Radio Berlin", countryCode: "DE", country: "Germany")
        ]
        XCTAssertEqual(StationFilter.filter(stations, query: "de").map(\.name), ["Radio Berlin"])
    }

    func testFilterMatchesTags() {
        let stations = [
            station("Jazz FM", tags: ["jazz", "smooth"]),
            station("Rock Radio", tags: ["rock", "metal"])
        ]
        XCTAssertEqual(StationFilter.filter(stations, query: "metal").map(\.name), ["Rock Radio"])
    }
}

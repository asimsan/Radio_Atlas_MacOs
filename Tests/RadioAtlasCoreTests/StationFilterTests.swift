import XCTest
@testable import RadioAtlasCore

final class StationFilterTests: XCTestCase {
    private func station(_ name: String) -> Station {
        Station(id: name, name: name, streamURL: URL(string: "https://s.example/\(name).mp3")!,
                homepage: nil, faviconURL: nil, tags: [], countryCode: "US", country: "United States",
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
}

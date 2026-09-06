// Tests/RadioAtlasCoreTests/RandomTunerTests.swift
import XCTest
@testable import RadioAtlasCore

final class RandomTunerTests: XCTestCase {
    private func station(_ id: String) -> Station {
        Station(id: id, name: id, streamURL: URL(string: "https://s.example/\(id).mp3")!,
                homepage: nil, faviconURL: nil, tags: [], countryCode: "US", country: "United States",
                latitude: nil, longitude: nil, votes: 0, clickCount: 0, bitrateKbps: 128)
    }

    func testExcludesRecentStationsWhenAlternativesExist() {
        let stations = [station("a"), station("b"), station("c")]
        let tuner = RandomTuner()

        for _ in 0..<50 {
            let picked = tuner.pickStation(from: stations, avoiding: ["a", "b"])
            XCTAssertEqual(picked?.id, "c")
        }
    }

    func testFallsBackToFullListWhenEverythingIsRecent() {
        let stations = [station("a"), station("b")]
        let tuner = RandomTuner()

        let picked = tuner.pickStation(from: stations, avoiding: ["a", "b"])

        XCTAssertNotNil(picked)
        XCTAssertTrue(["a", "b"].contains(picked!.id))
    }

    func testReturnsNilForEmptyList() {
        let tuner = RandomTuner()
        XCTAssertNil(tuner.pickStation(from: [], avoiding: []))
    }
}

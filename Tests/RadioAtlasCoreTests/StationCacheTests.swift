import XCTest
@testable import RadioAtlasCore

final class StationCacheTests: XCTestCase {
    private func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let sampleStation = Station(
        id: "a1", name: "Alpha", streamURL: URL(string: "https://s.example/a.mp3")!,
        homepage: nil, faviconURL: nil, tags: [], countryCode: "US", country: "United States",
        latitude: 40.0, longitude: -74.0, votes: 1, clickCount: 1, bitrateKbps: 128
    )

    func testWriteThenReadReturnsStationsWithinTTL() throws {
        let cache = StationCache(directory: makeTempDirectory(), filename: "top.json", ttl: 3600)
        try cache.write([sampleStation], now: Date())

        let result = cache.read(now: Date().addingTimeInterval(60))

        XCTAssertEqual(result, [sampleStation])
    }

    func testReadReturnsNilAfterTTLExpires() throws {
        let cache = StationCache(directory: makeTempDirectory(), filename: "top.json", ttl: 60)
        try cache.write([sampleStation], now: Date())

        let result = cache.read(now: Date().addingTimeInterval(120))

        XCTAssertNil(result)
    }

    func testReadReturnsNilWhenNoCacheFileExists() {
        let cache = StationCache(directory: makeTempDirectory(), filename: "missing.json", ttl: 3600)
        XCTAssertNil(cache.read())
    }
}

import XCTest
@testable import RadioAtlasCore

@MainActor
final class StationSearchCoordinatorTests: XCTestCase {
    // MARK: - Fixtures

    private func makeStation(_ id: String, name: String, code: String, country: String) -> Station {
        Station(
            id: id,
            name: name,
            streamURL: URL(string: "https://stream.example/\(id).mp3")!,
            homepage: nil,
            faviconURL: nil,
            tags: ["jazz"],
            countryCode: code,
            country: country,
            latitude: nil,
            longitude: nil,
            votes: 0,
            clickCount: 0,
            bitrateKbps: 0
        )
    }

    private var baseStations: [Station] {
        [
            makeStation("de-1", name: "Deutschlandfunk", code: "DE", country: "Germany"),
            makeStation("gb-1", name: "BBC Radio 1", code: "GB", country: "United Kingdom"),
            makeStation("us-1", name: "NPR", code: "US", country: "United States Of America"),
            makeStation("fr-1", name: "FIP", code: "FR", country: "France"),
            makeStation("xk-1", name: "Radio Kosova", code: "XK", country: "Kosovo"),
        ]
    }

    private let regionCodes: Set<String> = ["DE", "GB", "US", "FR"]

    private final class StubDirectory: StationDirectoryProviding, @unchecked Sendable {
        var countryResults: [String: [Station]] = [:]
        var delays: [String: TimeInterval] = [:]
        var error: Error?
        private(set) var requestedCodes: [String] = []

        func stationsByCountryCode(_ code: String) async throws -> [Station] {
            requestedCodes.append(code)
            if let delay = delays[code] {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if let error { throw error }
            return countryResults[code] ?? []
        }

        func topStations(limit: Int) async throws -> [Station] { [] }
    }

    private func makeCoordinator(
        _ directory: StubDirectory,
        debounceInterval: TimeInterval = 0
    ) -> StationSearchCoordinator {
        StationSearchCoordinator(directory: directory, regionCodes: regionCodes, debounceInterval: debounceInterval)
    }

    /// Polls until `condition` holds, failing the test after 2 seconds.
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("waitUntil timed out")
    }

    // MARK: - Local filtering

    func testNonCountryQueryFiltersBaseListLocally() {
        let coordinator = makeCoordinator(StubDirectory())
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("jazz")

        XCTAssertNil(coordinator.countryCode)
        XCTAssertEqual(coordinator.list.map(\.id), ["de-1", "gb-1", "us-1", "fr-1", "xk-1"])
    }

    func testEmptyQueryShowsFullBaseList() {
        let coordinator = makeCoordinator(StubDirectory())
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("")

        XCTAssertNil(coordinator.countryCode)
        XCTAssertEqual(coordinator.list.map(\.id), baseStations.map(\.id))
    }

    // MARK: - Country mode via query

    func testExactCountryNameQueryFetchesThatCountryList() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        XCTAssertEqual(coordinator.countryCode, "DE")
        XCTAssertEqual(coordinator.countryName, "Germany")
        XCTAssertEqual(directory.requestedCodes, ["DE"])
        XCTAssertFalse(coordinator.isLoadingCountry)
    }

    func testISOCodeQueryFetchesThatCountryList() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("de")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        XCTAssertEqual(coordinator.countryCode, "DE")
        XCTAssertEqual(directory.requestedCodes, ["DE"])
    }

    func testCountryNameMatchDoesNotRequireRegionGeometry() async {
        let directory = StubDirectory()
        directory.countryResults["XK"] = [makeStation("xk-full", name: "All Kosovo", code: "XK", country: "Kosovo")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("kosovo")
        await waitUntil { coordinator.list.map(\.id) == ["xk-full"] }

        XCTAssertEqual(coordinator.countryCode, "XK")
        XCTAssertEqual(directory.requestedCodes, ["XK"])
    }

    func testISOCodeNotInRegionCodesFallsBackToLocalFilter() {
        let coordinator = makeCoordinator(StubDirectory())
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("xk")

        XCTAssertNil(coordinator.countryCode)
        // Not country mode, but the local filter still matches the station
        // via its country code substring ("xk" in "XK") — real StationFilter.
        XCTAssertEqual(coordinator.list.map(\.id), ["xk-1"])
    }

    func testAmbiguousCountryPrefixFallsBackToLocalFilter() {
        let coordinator = makeCoordinator(StubDirectory())
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("united")

        XCTAssertNil(coordinator.countryCode)
        XCTAssertEqual(coordinator.list.map(\.id), ["gb-1", "us-1"])
    }

    // MARK: - Exiting country mode

    func testClearingQueryExitsSearchEnteredCountryMode() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)
        coordinator.setQuery("germany")
        await waitUntil { coordinator.countryCode == "DE" && !coordinator.isLoadingCountry }

        coordinator.setQuery("")

        XCTAssertNil(coordinator.countryCode)
        XCTAssertNil(coordinator.countryName)
        XCTAssertEqual(coordinator.list.map(\.id), baseStations.map(\.id))
    }

    func testGlobeBrowseSurvivesEmptyQueryChange() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.browseCountry(code: "DE", name: "Germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        coordinator.setQuery("")

        // Globe-origin browse is not exited by an (already empty) query.
        XCTAssertEqual(coordinator.countryCode, "DE")
        XCTAssertEqual(coordinator.list.map(\.id), ["de-full"])
    }

    func testTypingNonCountryQueryExitsGlobeBrowse() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)
        coordinator.browseCountry(code: "DE", name: "Germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        coordinator.setQuery("jazz")

        XCTAssertNil(coordinator.countryCode)
        XCTAssertEqual(coordinator.list.map(\.id), ["de-1", "gb-1", "us-1", "fr-1", "xk-1"])
    }

    func testExitCountryModeReturnsToBaseList() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)
        coordinator.browseCountry(code: "DE", name: "Germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        coordinator.exitCountryMode()

        XCTAssertNil(coordinator.countryCode)
        XCTAssertEqual(coordinator.list.map(\.id), baseStations.map(\.id))
    }

    // MARK: - Fetch hygiene

    func testRapidQueryChangesOnlyFetchForTheLastQuery() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory, debounceInterval: 0.05)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("ger")
        coordinator.setQuery("germ")
        coordinator.setQuery("germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        XCTAssertEqual(directory.requestedCodes, ["DE"])
    }

    func testSlowStaleResponseIsDiscarded() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        directory.countryResults["FR"] = [makeStation("fr-full", name: "All French", code: "FR", country: "France")]
        directory.delays["DE"] = 0.1
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("germany")
        coordinator.setQuery("france")
        await waitUntil { coordinator.list.map(\.id) == ["fr-full"] }

        // Let the slow German response land (or get cancelled) and confirm it
        // never overwrites the newer French result.
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(coordinator.list.map(\.id), ["fr-full"])
        XCTAssertEqual(coordinator.countryCode, "FR")
    }

    func testRepeatedSameCountryQueryDoesNotRefetch() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }
        coordinator.setQuery("germany")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(directory.requestedCodes, ["DE"])
    }

    // MARK: - Failure handling

    func testFetchFailureKeepsPreviousListAndSurfacesError() async {
        struct Boom: Error {}
        let directory = StubDirectory()
        directory.error = Boom()
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)

        coordinator.setQuery("germany")
        await waitUntil { coordinator.countryError != nil }

        XCTAssertEqual(coordinator.list.map(\.id), baseStations.map(\.id))
        XCTAssertEqual(coordinator.countryCode, "DE")
        XCTAssertFalse(coordinator.isLoadingCountry)
        XCTAssertTrue(coordinator.countryError?.contains("Germany") ?? false)
    }

    func testSetBaseStationsDoesNotClobberActiveCountryList() async {
        let directory = StubDirectory()
        directory.countryResults["DE"] = [makeStation("de-full", name: "All German", code: "DE", country: "Germany")]
        let coordinator = makeCoordinator(directory)
        coordinator.setBaseStations(baseStations)
        coordinator.browseCountry(code: "DE", name: "Germany")
        await waitUntil { coordinator.list.map(\.id) == ["de-full"] }

        coordinator.setBaseStations([makeStation("new-1", name: "New Top", code: "US", country: "United States Of America")])

        XCTAssertEqual(coordinator.list.map(\.id), ["de-full"])
        XCTAssertEqual(coordinator.countryCode, "DE")
    }
}

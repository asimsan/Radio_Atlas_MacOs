import XCTest
@testable import RadioAtlasCore

final class CountryLookupTests: XCTestCase {
    private func loadLookup() throws -> CountryLookup {
        let url = Bundle.module.url(forResource: "countries-110m", withExtension: "geojson")!
        return try CountryLookup(geoJSONData: try Data(contentsOf: url))
    }

    func testFindsCountryForKnownCoordinate() throws {
        let lookup = try loadLookup()
        // Paris, France
        let code = lookup.countryCode(at: GeoPoint(latitude: 48.8566, longitude: 2.3522))
        XCTAssertEqual(code, "FR")
    }

    func testReturnsNilOverOpenOcean() throws {
        let lookup = try loadLookup()
        // Open Pacific, far from any coastline
        let code = lookup.countryCode(at: GeoPoint(latitude: 0.0, longitude: -150.0))
        XCTAssertNil(code)
    }
}

// MARK: - Bundled resource loading

/// `loadBundled()` resolves its resource differently under `swift run`/tests
/// (SwiftPM's `Bundle.module`) than inside the packaged `.app`
/// (`Bundle.main`'s `Contents/Resources`). This covers the former; breaking it
/// would otherwise only surface as an empty globe at runtime, because
/// `PanelViewModel` swallows the failure with `try?`.
final class CountryLookupBundledTests: XCTestCase {
    func testLoadBundledResolvesResourceAndParsesRegions() throws {
        let lookup = try CountryLookup.loadBundled()
        XCTAssertFalse(lookup.allRegions().isEmpty)
    }
}

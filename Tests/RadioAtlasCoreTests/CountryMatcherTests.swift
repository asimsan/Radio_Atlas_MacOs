import XCTest
@testable import RadioAtlasCore

final class CountryMatcherTests: XCTestCase {
    private func makeStation(name: String, code: String, country: String) -> Station {
        Station(
            id: "id-\(code)-\(name)",
            name: name,
            streamURL: URL(string: "https://stream.example/\(name).mp3")!,
            homepage: nil,
            faviconURL: nil,
            tags: [],
            countryCode: code,
            country: country,
            latitude: nil,
            longitude: nil,
            votes: 0,
            clickCount: 0,
            bitrateKbps: 0
        )
    }

    private var stations: [Station] {
        [
            makeStation(name: "Deutschlandfunk", code: "DE", country: "Germany"),
            makeStation(name: "BBC Radio 1", code: "GB", country: "United Kingdom"),
            makeStation(name: "NPR", code: "US", country: "United States Of America"),
            makeStation(name: "FIP", code: "FR", country: "France"),
        ]
    }

    private let regionCodes: Set<String> = ["DE", "GB", "US", "FR"]

    func testExactCountryNameMatchesCaseInsensitively() {
        XCTAssertEqual(
            CountryMatcher.match("germany", stations: stations, regionCodes: regionCodes),
            CountryMatch(isoCode: "DE", name: "Germany")
        )
    }

    func testExactCountryNameIgnoresExtraWhitespace() {
        XCTAssertEqual(
            CountryMatcher.match("  united kingdom  ", stations: stations, regionCodes: regionCodes),
            CountryMatch(isoCode: "GB", name: "United Kingdom")
        )
    }

    func testISOCodeMatchesLowercaseAndUppercase() {
        XCTAssertEqual(
            CountryMatcher.match("de", stations: stations, regionCodes: regionCodes),
            CountryMatch(isoCode: "DE", name: "Germany")
        )
        XCTAssertEqual(
            CountryMatcher.match("DE", stations: stations, regionCodes: regionCodes),
            CountryMatch(isoCode: "DE", name: "Germany")
        )
    }

    func testUniqueNamePrefixMatches() {
        XCTAssertEqual(
            CountryMatcher.match("germ", stations: stations, regionCodes: regionCodes),
            CountryMatch(isoCode: "DE", name: "Germany")
        )
    }

    func testMoreSpecificPrefixDisambiguates() {
        XCTAssertEqual(
            CountryMatcher.match("united s", stations: stations, regionCodes: regionCodes),
            CountryMatch(isoCode: "US", name: "United States Of America")
        )
    }

    func testAmbiguousPrefixReturnsNil() {
        XCTAssertNil(CountryMatcher.match("united", stations: stations, regionCodes: regionCodes))
    }

    func testNonCountryQueryReturnsNil() {
        XCTAssertNil(CountryMatcher.match("jazz", stations: stations, regionCodes: regionCodes))
    }

    func testEmptyOrWhitespaceQueryReturnsNil() {
        XCTAssertNil(CountryMatcher.match("", stations: stations, regionCodes: regionCodes))
        XCTAssertNil(CountryMatcher.match("   ", stations: stations, regionCodes: regionCodes))
    }
}

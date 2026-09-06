import XCTest
@testable import RadioAtlasCore

final class CountryTimeZonesTests: XCTestCase {
    func testSingleZoneCountryMapsToItsIANAZone() {
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "DE", longitude: nil)?.identifier,
            "Europe/Berlin"
        )
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "FR", longitude: nil)?.identifier,
            "Europe/Paris"
        )
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "GB", longitude: nil)?.identifier,
            "Europe/London"
        )
    }

    func testHalfAndQuarterHourOffsetsAreRespected() {
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "IN", longitude: nil)?.secondsFromGMT(),
            5 * 3600 + 30 * 60 // +5:30
        )
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "NP", longitude: nil)?.secondsFromGMT(),
            5 * 3600 + 45 * 60 // +5:45
        )
    }

    func testMultiZoneCountryUsesStationLongitude() {
        // A Los Angeles station (-118°) lands in Pacific time.
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "US", longitude: -118)?.identifier,
            "America/Los_Angeles"
        )
        // A New York station (-74°) lands in Eastern time.
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "US", longitude: -74)?.identifier,
            "America/New_York"
        )
    }

    func testMultiZoneCountryWithoutLongitudeUsesFirstZone() {
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "US", longitude: nil)?.identifier,
            "Pacific/Honolulu"
        )
    }

    func testUnknownCountryFallsBackToLongitudeBasedOffset() {
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "XX", longitude: 30)?.secondsFromGMT(),
            2 * 3600 // 30°E → UTC+2
        )
        XCTAssertEqual(
            CountryTimeZones.timeZone(countryCode: "XX", longitude: -75)?.secondsFromGMT(),
            -5 * 3600 // 75°W → UTC-5
        )
    }

    func testUnknownCountryWithoutLongitudeReturnsNil() {
        XCTAssertNil(CountryTimeZones.timeZone(countryCode: "XX", longitude: nil))
    }

    // MARK: - cityName

    func testCityNameUsesLastZonePathComponent() {
        XCTAssertEqual(CountryTimeZones.cityName(forIdentifier: "Europe/Berlin"), "Berlin")
        XCTAssertEqual(CountryTimeZones.cityName(forIdentifier: "Asia/Tokyo"), "Tokyo")
        XCTAssertEqual(CountryTimeZones.cityName(forIdentifier: "America/Argentina/Buenos_Aires"), "Buenos Aires")
    }

    func testCityNameReplacesUnderscoresWithSpaces() {
        XCTAssertEqual(CountryTimeZones.cityName(forIdentifier: "America/New_York"), "New York")
        XCTAssertEqual(CountryTimeZones.cityName(forIdentifier: "America/Los_Angeles"), "Los Angeles")
    }

    func testCityNameIsNilForZonesWithoutCityName() {
        XCTAssertNil(CountryTimeZones.cityName(forIdentifier: "GMT+0200"))
        XCTAssertNil(CountryTimeZones.cityName(forIdentifier: "UTC"))
        XCTAssertNil(CountryTimeZones.cityName(forIdentifier: ""))
    }
}

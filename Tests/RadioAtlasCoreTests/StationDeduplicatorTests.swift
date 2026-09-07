import XCTest
@testable import RadioAtlasCore

final class StationDeduplicatorTests: XCTestCase {
    private func station(
        _ id: String, name: String, url: String, country: String = "FR",
        clicks: Int = 0, bitrate: Int = 0
    ) -> Station {
        Station(id: id, name: name, streamURL: URL(string: url)!, homepage: nil,
                faviconURL: nil, tags: [], countryCode: country, country: country,
                latitude: nil, longitude: nil, votes: 0, clickCount: clicks,
                bitrateKbps: bitrate)
    }

    func testEmptyInput() {
        XCTAssertTrue(StationDeduplicator.deduplicate([]).isEmpty)
    }

    func testDistinctStationsAreAllKeptInOriginalOrder() {
        let input = [
            station("1", name: "Alpha", url: "https://a.example/s"),
            station("2", name: "Beta", url: "https://b.example/s"),
            station("3", name: "Gamma", url: "https://c.example/s"),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).map(\.id), ["1", "2", "3"])
    }

    /// "102.7 KIIS FM" and "KIIS FM 102.7" in the live data — same audio.
    func testSameStreamURLCollapsesToMostPlayed() {
        let input = [
            station("quiet", name: "KIIS FM 102.7", url: "https://s.example/z", clicks: 417),
            station("loud", name: "102.7 KIIS FM", url: "https://s.example/z", clicks: 1319),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).map(\.id), ["loud"])
    }

    /// "France Info" listed three times at different bitrates.
    func testSameNameAndCountryCollapsesToMostPlayed() {
        let input = [
            station("a", name: "France Info", url: "https://1.example/s", clicks: 1006, bitrate: 128),
            station("b", name: "France Info", url: "https://2.example/s", clicks: 186, bitrate: 192),
            station("c", name: "France Info", url: "https://3.example/s", clicks: 94, bitrate: 0),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).map(\.id), ["a"])
    }

    func testBitrateBreaksAClickCountTie() {
        let input = [
            station("low", name: "Tie", url: "https://1.example/s", clicks: 50, bitrate: 64),
            station("high", name: "Tie", url: "https://2.example/s", clicks: 50, bitrate: 192),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).map(\.id), ["high"])
    }

    /// Same name in different countries is NOT a duplicate — "Radio 1" exists
    /// independently in many countries.
    func testSameNameInDifferentCountriesIsKept() {
        let input = [
            station("gb", name: "Radio 1", url: "https://gb.example/s", country: "GB"),
            station("nl", name: "Radio 1", url: "https://nl.example/s", country: "NL"),
        ]
        XCTAssertEqual(Set(StationDeduplicator.deduplicate(input).map(\.id)), ["gb", "nl"])
    }

    /// Regression guard: an ASCII-stripping normalizer collapses Cyrillic,
    /// Arabic and CJK names to the empty string, which would merge every
    /// non-Latin station in a country into one. Verified against the live
    /// cache, where that bug produced 9 bogus "duplicates" for Russia alone.
    func testNonLatinNamesAreNotCollapsedTogether() {
        let input = [
            station("ru1", name: "Русское Радио", url: "https://1.example/s", country: "RU"),
            station("ru2", name: "Эхо Москвы", url: "https://2.example/s", country: "RU"),
            station("eg1", name: "إذاعة القرآن", url: "https://3.example/s", country: "EG"),
            station("eg2", name: "نجوم إف إم", url: "https://4.example/s", country: "EG"),
            station("cn1", name: "中央人民广播电台", url: "https://5.example/s", country: "CN"),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).count, 5)
    }

    func testNameMatchingIgnoresCaseAccentsAndSeparators() {
        let input = [
            station("keep", name: "Radio Café", url: "https://1.example/s", clicks: 10),
            station("drop", name: "radio  cafe", url: "https://2.example/s", clicks: 5),
            station("drop2", name: "RADIO-CAFE", url: "https://3.example/s", clicks: 1),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).map(\.id), ["keep"])
    }

    /// A favourited or recently played station must never be dropped, or it
    /// would silently vanish from the Favourites tab, which resolves by id.
    func testProtectedStationSurvivesEvenWhenLowerRanked() {
        let input = [
            station("popular", name: "France Info", url: "https://1.example/s", clicks: 1006),
            station("favourite", name: "France Info", url: "https://2.example/s", clicks: 3),
        ]
        let result = StationDeduplicator.deduplicate(input, protectedIDs: ["favourite"])
        XCTAssertTrue(result.contains { $0.id == "favourite" })
    }

    /// Names that normalize to nothing (punctuation only) must not all
    /// collapse into a single station.
    func testPunctuationOnlyNamesDoNotCollapse() {
        let input = [
            station("x", name: "---", url: "https://1.example/s", country: "FR"),
            station("y", name: "...", url: "https://2.example/s", country: "FR"),
        ]
        XCTAssertEqual(StationDeduplicator.deduplicate(input).count, 2)
    }

    func testTieBreakIsDeterministic() {
        let a = station("aaa", name: "Same", url: "https://1.example/s")
        let b = station("bbb", name: "Same", url: "https://2.example/s")
        XCTAssertEqual(StationDeduplicator.deduplicate([a, b]).map(\.id),
                       StationDeduplicator.deduplicate([b, a]).map(\.id))
    }
}

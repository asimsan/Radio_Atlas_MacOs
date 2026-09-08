import Foundation

public struct Station: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let streamURL: URL
    public let homepage: URL?
    public let faviconURL: URL?
    public let tags: [String]
    public let countryCode: String
    public let country: String
    public let latitude: Double?
    public let longitude: Double?
    public let votes: Int
    public let clickCount: Int
    public let bitrateKbps: Int
}

/// Mirrors the raw field names returned by the Radio Browser API
/// (https://api.radio-browser.info) so JSON decoding is a straight mapping.
public struct RawStation: Decodable {
    public let stationuuid: String
    public let name: String
    public let url_resolved: String
    /// Optional: absent from station lists cached before this field was read.
    public let url: String?
    public let homepage: String?
    public let favicon: String?
    public let tags: String
    public let countrycode: String
    public let country: String
    public let geo_lat: Double?
    public let geo_long: Double?
    public let votes: Int
    public let clickcount: Int
    public let bitrate: Int
}

public extension Station {
    init?(raw: RawStation) {
        // Radio Browser leaves `url_resolved` empty until its own resolver has
        // followed the station's URL; the raw `url` still plays. Requiring the
        // resolved one silently dropped those stations from every list, which
        // is how Butwal FM (Nepal) went missing while the website showed it.
        // It skews towards smaller stations: 16 of the top 10,000, but a
        // higher share further down the directory.
        let candidateURL = raw.url_resolved.isEmpty ? (raw.url ?? "") : raw.url_resolved
        guard !raw.stationuuid.isEmpty, let streamURL = URL(string: candidateURL) else { return nil }
        id = raw.stationuuid
        name = raw.name
        self.streamURL = streamURL
        homepage = raw.homepage.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        faviconURL = raw.favicon.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        tags = raw.tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        countryCode = raw.countrycode
        country = raw.country
        latitude = raw.geo_lat
        longitude = raw.geo_long
        votes = raw.votes
        clickCount = raw.clickcount
        bitrateKbps = raw.bitrate
    }
}

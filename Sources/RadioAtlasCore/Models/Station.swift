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

    // Swift's implicit memberwise initializer for a `public` struct is only
    // `internal`, so it was usable from `@testable import` test targets
    // (Tasks 2/6/9) but not from the `RadioAtlas` app target. Task 9's
    // `AVPlayerStreamPlayer` needs to construct a `Station` value from a bare
    // URL (see its doc comment for why), which is otherwise impossible from
    // outside this module — `init(raw:)` requires a `RawStation`, and
    // `Decodable`'s synthesized `init(from:)` requires a `Decoder`. This
    // explicit `public` init has the identical signature/order as the
    // implicit one it replaces, so it changes no behavior for any existing
    // caller; it only widens access.
    public init(id: String, name: String, streamURL: URL, homepage: URL?, faviconURL: URL?, tags: [String],
                countryCode: String, country: String, latitude: Double?, longitude: Double?,
                votes: Int, clickCount: Int, bitrateKbps: Int) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.homepage = homepage
        self.faviconURL = faviconURL
        self.tags = tags
        self.countryCode = countryCode
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.votes = votes
        self.clickCount = clickCount
        self.bitrateKbps = bitrateKbps
    }
}

/// Mirrors the raw field names returned by the Radio Browser API
/// (https://api.radio-browser.info) so JSON decoding is a straight mapping.
public struct RawStation: Decodable {
    public let stationuuid: String
    public let name: String
    public let url_resolved: String
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
        guard !raw.stationuuid.isEmpty, let streamURL = URL(string: raw.url_resolved) else { return nil }
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

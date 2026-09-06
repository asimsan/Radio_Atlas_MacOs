import Foundation

/// One grid point of the NOAA SWPC OVATION aurora model.
public struct OvationPoint: Equatable {
    public let longitude: Double
    public let latitude: Double
    public let aurora: Double

    public init(longitude: Double, latitude: Double, aurora: Double) {
        self.longitude = longitude
        self.latitude = latitude
        self.aurora = aurora
    }
}

/// Decoded `ovation_aurora_latest.json` — a 360×181 grid whose entries are
/// `[Longitude, Latitude, Aurora]` triples (see the feed's own "Data Format"
/// field). The other top-level fields are ignored.
public struct OvationAuroraData: Decodable {
    public let coordinates: [OvationPoint]

    public init(coordinates: [OvationPoint]) {
        self.coordinates = coordinates
    }

    private enum CodingKeys: String, CodingKey { case coordinates }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode([[Double]].self, forKey: .coordinates)
        coordinates = raw.compactMap { triple in
            guard triple.count >= 3 else { return nil }
            return OvationPoint(longitude: triple[0], latitude: triple[1], aurora: triple[2])
        }
    }
}

import Foundation

public struct GeoPoint: Equatable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct CountryLookup {
    private struct Region {
        let isoCode: String
        let rings: [[GeoPoint]]
    }

    private let regions: [Region]

    public init(geoJSONData: Data) throws {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: geoJSONData)
        regions = collection.features.compactMap { feature in
            guard let isoCode = feature.properties.isoA2, isoCode != "-99" else { return nil }
            let rings = feature.geometry.polygonRings()
            guard !rings.isEmpty else { return nil }
            return Region(isoCode: isoCode, rings: rings)
        }
    }

    public func countryCode(at point: GeoPoint) -> String? {
        for region in regions {
            if region.rings.contains(where: { Self.pointInPolygon(point, ring: $0) }) {
                return region.isoCode
            }
        }
        return nil
    }

    /// Standard ray-casting point-in-polygon test.
    static func pointInPolygon(_ point: GeoPoint, ring: [GeoPoint]) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let pi = ring[i]
            let pj = ring[j]
            let intersects = ((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) &&
                (point.latitude < (pj.latitude - pi.latitude) * (point.longitude - pi.longitude) / (pj.longitude - pi.longitude) + pi.latitude)
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }
}

// MARK: - Minimal GeoJSON decoding

private struct GeoJSONFeatureCollection: Decodable {
    let features: [GeoJSONFeature]
}

private struct GeoJSONFeature: Decodable {
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}

private struct GeoJSONProperties: Decodable {
    let isoA2: String?
    // The downloaded Natural Earth dataset's plain `ISO_A2` field is "-99" for a
    // handful of countries with overseas territories/disputed status (notably
    // France and Norway), because ISO_A2 is ambiguous between the metropolitan
    // country and its full sovereign extent. `ISO_A2_EH` ("ISO_A2, extra-handled")
    // is Natural Earth's variant that resolves those cases to the expected
    // two-letter code (e.g. "FR", "NO") while still leaving genuinely
    // unrecognized/disputed territories (e.g. Somaliland, N. Cyprus) as "-99".
    enum CodingKeys: String, CodingKey { case isoA2 = "ISO_A2_EH" }
}

private struct GeoJSONGeometry: Decodable {
    let type: String
    // Polygon: [ring][point][lon, lat]; MultiPolygon: [polygon][ring][point][lon, lat]
    let polygonCoordinates: [[[Double]]]?
    let multiPolygonCoordinates: [[[[Double]]]]?

    private enum CodingKeys: String, CodingKey { case type, coordinates }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        if type == "Polygon" {
            polygonCoordinates = try container.decode([[[Double]]].self, forKey: .coordinates)
            multiPolygonCoordinates = nil
        } else if type == "MultiPolygon" {
            polygonCoordinates = nil
            multiPolygonCoordinates = try container.decode([[[[Double]]]].self, forKey: .coordinates)
        } else {
            polygonCoordinates = nil
            multiPolygonCoordinates = nil
        }
    }

    func polygonRings() -> [[GeoPoint]] {
        func toPoints(_ ring: [[Double]]) -> [GeoPoint] {
            ring.map { GeoPoint(latitude: $0[1], longitude: $0[0]) }
        }
        if let rings = polygonCoordinates {
            return rings.map(toPoints)
        }
        if let polygons = multiPolygonCoordinates {
            return polygons.flatMap { $0.map(toPoints) }
        }
        return []
    }
}

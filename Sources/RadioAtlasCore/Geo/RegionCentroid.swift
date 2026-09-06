import Foundation

/// Area-weighted polygon centroid of a country's rings, used to aim the
/// globe's auto-rotation at the country that started playing.
public enum RegionCentroid {
    /// Returns nil when the region has no usable ring (fewer than 3 points).
    public static func centroid(of region: CountryRegion) -> GeoPoint? {
        var totalWeight = 0.0
        var weightedLatitude = 0.0
        var weightedLongitude = 0.0
        var foundRing = false

        for ring in region.rings where ring.count >= 3 {
            // Unwrap longitudes relative to the ring's first point so a ring
            // straddling ±180° (Russia, Fiji) averages its points instead of
            // producing a bogus near-zero centroid.
            let baseLongitude = ring[0].longitude
            let unwrapped = ring.map { point -> (latitude: Double, longitude: Double) in
                var longitude = point.longitude - baseLongitude
                if longitude > 180 { longitude -= 360 }
                if longitude < -180 { longitude += 360 }
                return (point.latitude, longitude)
            }

            // Shoelace signed area and polygon centroid, computed in
            // unwrapped space. (x = longitude, y = latitude.)
            var signedArea = 0.0
            var centroidLongitude = 0.0
            var centroidLatitude = 0.0
            for index in 0..<unwrapped.count {
                let a = unwrapped[index]
                let b = unwrapped[(index + 1) % unwrapped.count]
                let cross = a.longitude * b.latitude - b.longitude * a.latitude
                signedArea += cross
                centroidLongitude += (a.longitude + b.longitude) * cross
                centroidLatitude += (a.latitude + b.latitude) * cross
            }
            signedArea *= 0.5
            guard abs(signedArea) > 1e-12 else { continue }

            centroidLongitude /= (6 * signedArea)
            centroidLatitude /= (6 * signedArea)

            let weight = abs(signedArea)
            totalWeight += weight
            weightedLongitude += weight * (centroidLongitude + baseLongitude)
            weightedLatitude += weight * centroidLatitude
            foundRing = true
        }

        guard foundRing, totalWeight > 1e-12 else { return nil }

        var longitude = weightedLongitude / totalWeight
        if longitude > 180 { longitude -= 360 }
        if longitude <= -180 { longitude += 360 }
        return GeoPoint(latitude: weightedLatitude / totalWeight, longitude: longitude)
    }
}

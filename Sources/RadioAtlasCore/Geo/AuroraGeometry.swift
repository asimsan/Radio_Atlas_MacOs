import Foundation

/// Which pole an aurora band surrounds.
public enum AuroraPole {
    case north
    case south

    /// +1 north, -1 south — latitudes scale by this sign.
    public var sign: Double {
        switch self {
        case .north: return 1
        case .south: return -1
        }
    }
}

/// Pure math for the aurora bands drawn around the globe's poles — wavy
/// latitude edges and closed sample rings — kept in Core so the animation's
/// geometry is unit-testable independently of the Canvas rendering.
public enum AuroraGeometry {
    /// The wavy latitude of a band edge at the given longitude: the band
    /// center plus a sine ripple, with `phase` (radians) advancing over time
    /// to make the band drift around the pole.
    public static func edgeLatitude(base: Double, amplitude: Double, waveCount: Double, longitude: Double, phase: Double) -> Double {
        let radians = longitude * .pi / 180
        return base + amplitude * sin(waveCount * radians + phase)
    }

    /// A closed ring of points around a pole at a constant latitude,
    /// `samples` steps of 360°/samples apart starting at longitude -180°,
    /// with the first point repeated at the end so the ring closes.
    public static func ring(pole: AuroraPole, latitude: Double, samples: Int = 72) -> [GeoPoint] {
        guard samples > 0 else { return [] }
        let signedLatitude = latitude * pole.sign
        let step = 360.0 / Double(samples)
        var points = (0..<samples).map { index in
            GeoPoint(latitude: signedLatitude, longitude: -180 + Double(index) * step)
        }
        // Repeat the first point exactly rather than computing -180 + 360:
        // floating-point drift would make the "closing" point 180.0, breaking
        // the exact-closure contract.
        points.append(points[0])
        return points
    }

    /// A closed ring whose latitude ripples with the wave (a "curtain" edge),
    /// for band rendering: `ring` supplies the longitudes, `edgeLatitude`
    /// displaces each point's latitude.
    public static func wavyRing(pole: AuroraPole, base: Double, amplitude: Double, waveCount: Double, phase: Double, samples: Int = 72) -> [GeoPoint] {
        ring(pole: pole, latitude: 0, samples: samples).map { point in
            let latitude = pole.sign * edgeLatitude(
                base: base,
                amplitude: amplitude,
                waveCount: waveCount,
                longitude: point.longitude,
                phase: phase
            )
            return GeoPoint(latitude: latitude, longitude: point.longitude)
        }
    }
}

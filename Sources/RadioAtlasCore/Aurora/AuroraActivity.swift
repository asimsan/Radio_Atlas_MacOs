import Foundation

/// Summarized aurora activity for one hemisphere, reduced from the OVATION
/// grid so the renderer only needs two scalars per pole.
public struct HemisphereActivity: Equatable {
    /// 0 (quiet) … 1 (storm), normalized from the spread of significant
    /// values relative to the hemisphere's peak.
    public let intensity: Double
    /// The 10th-percentile |latitude| of significant activity — a robust
    /// measure of how far the auroral oval reaches from the pole. Nil when
    /// the hemisphere has no activity in this feed.
    public let equatorwardLatitude: Double?

    public init(intensity: Double, equatorwardLatitude: Double?) {
        self.intensity = intensity
        self.equatorwardLatitude = equatorwardLatitude
    }
}

public struct AuroraActivity: Equatable {
    public let north: HemisphereActivity
    public let south: HemisphereActivity
}

public enum AuroraActivityReducer {
    /// Fraction of the hemisphere's peak above which a grid point counts as
    /// significant aurora (relative — works across quiet and storm feeds).
    static let thresholdFraction = 0.5
    /// Percentile of significant |latitudes| used for the equatorward extent,
    /// so a stray outer grid point doesn't drag the bands toward the equator.
    static let extentPercentile = 10.0

    public static func derive(from data: OvationAuroraData) -> AuroraActivity {
        AuroraActivity(
            north: hemisphere(data.coordinates.filter { $0.latitude > 0 }),
            south: hemisphere(data.coordinates.filter { $0.latitude < 0 })
        )
    }

    private static func hemisphere(_ points: [OvationPoint]) -> HemisphereActivity {
        let active = points.filter { $0.aurora > 0 }
        guard let peak = active.map(\.aurora).max(), peak > 0 else {
            return HemisphereActivity(intensity: 0, equatorwardLatitude: nil)
        }
        let threshold = thresholdFraction * peak
        let significant = active.filter { $0.aurora >= threshold }
        guard !significant.isEmpty else {
            return HemisphereActivity(intensity: 0, equatorwardLatitude: nil)
        }

        // Mean of significant values relative to peak lies in [0.5, 1];
        // stretch to [0, 1].
        let meanRatio = significant.map(\.aurora).reduce(0, +) / Double(significant.count) / peak
        let intensity = min(1, max(0, (meanRatio - 0.5) * 2))

        let latitudes = significant.map { abs($0.latitude) }.sorted()
        let percentileIndex = min(latitudes.count - 1, max(0, Int(Double(latitudes.count - 1) * extentPercentile / 100)))
        return HemisphereActivity(intensity: intensity, equatorwardLatitude: latitudes[percentileIndex])
    }
}

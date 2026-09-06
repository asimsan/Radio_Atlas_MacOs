import Foundation

/// The latitude edges of one aurora band (degrees from the equator).
public struct LatitudeBand: Equatable {
    public let inner: Double
    public let outer: Double

    public init(inner: Double, outer: Double) {
        self.inner = inner
        self.outer = outer
    }
}

/// Visual configuration of one pole's two aurora bands, derived from live
/// `HemisphereActivity`: stronger geomagnetic conditions widen and brighten
/// the bands and push them toward the equator.
public struct AuroraBandConfig: Equatable {
    public var innerBand: LatitudeBand
    public var outerBand: LatitudeBand
    /// Ripple amplitude of the wavy band edges (degrees).
    public var amplitude: Double
    /// Multiplier on the renderer's base band opacities.
    public var opacityMultiplier: Double

    /// The static look used when no live data is available (and the design
    /// the live mapping was calibrated around).
    public static let fallback = AuroraBandConfig(
        innerBand: LatitudeBand(inner: 61, outer: 68),
        outerBand: LatitudeBand(inner: 68, outer: 75),
        amplitude: 3.5,
        opacityMultiplier: 1
    )

    /// Activity beyond these latitudes is clamped — outside the range the
    /// orthographic view can show meaningfully.
    static let minimumExtent = 50.0
    static let maximumExtent = 80.0

    public static func resolve(activity: HemisphereActivity?) -> AuroraBandConfig {
        guard let activity, activity.intensity > 0, let extent = activity.equatorwardLatitude else {
            return .fallback
        }
        let clamped = min(maximumExtent, max(minimumExtent, extent))
        let bandWidth = 6.0
        return AuroraBandConfig(
            innerBand: LatitudeBand(inner: clamped, outer: clamped + bandWidth),
            outerBand: LatitudeBand(inner: clamped + bandWidth, outer: clamped + 2 * bandWidth),
            amplitude: 2.5 + 2.5 * activity.intensity,
            opacityMultiplier: 0.6 + 0.9 * activity.intensity
        )
    }

    /// Linear interpolation toward `other` (factor 0 = self, 1 = other),
    /// used to smooth config changes as fresh activity data arrives.
    public func mixed(with other: AuroraBandConfig, factor: Double) -> AuroraBandConfig {
        let t = min(1, max(0, factor))
        func lerp(_ from: Double, _ to: Double) -> Double { from + (to - from) * t }
        return AuroraBandConfig(
            innerBand: LatitudeBand(
                inner: lerp(innerBand.inner, other.innerBand.inner),
                outer: lerp(innerBand.outer, other.innerBand.outer)
            ),
            outerBand: LatitudeBand(
                inner: lerp(outerBand.inner, other.outerBand.inner),
                outer: lerp(outerBand.outer, other.outerBand.outer)
            ),
            amplitude: lerp(amplitude, other.amplitude),
            opacityMultiplier: lerp(opacityMultiplier, other.opacityMultiplier)
        )
    }
}

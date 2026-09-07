import Foundation

/// The globe's zoom arithmetic, kept out of the view layer so it can be
/// tested — `GlobeInteractionState` lives in the app target, which has no
/// test target of its own.
///
/// Bounds match the original omarchy-radio-atlas `Globe.qml` (scale 0.72–24).
public enum GlobeZoom {
    public static let minimumScale: Double = 0.72
    public static let maximumScale: Double = 24

    /// Fraction of the current scale gained per unit of scroll delta. Applied
    /// proportionally so one notch feels the same however far in you already
    /// are, instead of crawling once zoomed.
    public static let wheelSensitivity: Double = 0.02

    public static func clamp(scale: Double) -> Double {
        max(minimumScale, min(maximumScale, scale))
    }

    /// AppKit reports scroll-up as a *negative* `scrollingDeltaY`, and scroll-up
    /// means zoom in — hence the sign flip.
    public static func scaleAfterWheel(scale: Double, scrollingDeltaY: Double) -> Double {
        clamp(scale: scale + -scrollingDeltaY * wheelSensitivity * scale)
    }
}

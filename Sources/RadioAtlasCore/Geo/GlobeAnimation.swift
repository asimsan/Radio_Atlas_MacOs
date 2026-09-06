import Foundation

/// Pure math for animating the globe's center — kept free of SwiftUI so it
/// lives in Core with unit tests and the app-layer interaction state stays a
/// thin state machine around it.
public enum GlobeAnimation {
    /// Signed shortest-arc longitude delta in (-180, 180], so rotating from
    /// 170°E to 170°W travels +20° across the dateline instead of -340°.
    public static func longitudeDelta(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    /// Cubic ease-in-out: slow start, fast middle, slow settle.
    public static func easeInOut(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        if clamped < 0.5 {
            return 4 * clamped * clamped * clamped
        }
        return 1 - pow(-2 * clamped + 2, 3) / 2
    }
}

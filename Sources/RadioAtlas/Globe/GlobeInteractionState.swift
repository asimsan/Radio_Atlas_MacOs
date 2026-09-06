import Combine
import Foundation

/// Owns the globe's rotation/zoom state and the drag/kinetic-coast physics,
/// separated from `GlobeCanvasView`'s drawing code so the interaction logic
/// reads as plain, focused state transitions.
///
/// Matches the original omarchy-radio-atlas `Globe.qml` defaults and
/// sensitivity constants (see the design spec's Visual Design Reference).
@MainActor
final class GlobeInteractionState: ObservableObject {
    @Published var centerLatitude: Double = 18
    @Published var centerLongitude: Double = -20
    @Published var scale: Double = 1

    static let minimumScale: Double = 0.72
    static let maximumScale: Double = 24
    static let longitudeSensitivity: Double = 0.22
    static let latitudeSensitivity: Double = 0.18

    /// Degrees/sec^2 — how fast the kinetic coast slows down.
    static let kineticDeceleration: Double = 1800
    /// Degrees/sec — coast speed is capped here even if the release flick was faster.
    static let kineticMaximumSpeed: Double = 2400
    /// Degrees/sec — a release slower than this doesn't start a coast at all,
    /// and a coasting decay that drops below this stops immediately.
    static let kineticLaunchSpeed: Double = 120

    /// Current kinetic-coast angular velocity (degrees/sec), decomposed so that
    /// `centerLongitude += velocityLongitude * dt` / `centerLatitude += velocityLatitude * dt`
    /// reproduces the same direction of travel the drag was moving in.
    ///
    /// `@Published`, not just `private(set)`: `GlobeCanvasView` reads `isCoasting`
    /// to drive `TimelineView(.animation(paused: !isCoasting))`, and `ObservableObject`'s
    /// synthesized `objectWillChange` only fires for `@Published` properties. Without
    /// this, mutating `isCoasting` here wouldn't by itself trigger a re-render — a prior
    /// version of this file relied on an unrelated `@State` write in `GlobeCanvasView`'s
    /// drag `.onEnded` to incidentally force that re-render, which is a fragile,
    /// implicit dependency across two files. Making it `@Published` makes the
    /// dependency explicit and correct regardless of what else changes in the view.
    @Published private(set) var velocityLongitude: Double = 0
    @Published private(set) var velocityLatitude: Double = 0
    @Published private(set) var isCoasting: Bool = false

    private var lastDragTimestamp: Date?

    /// Call with the incremental (not cumulative) drag translation since the last call.
    func applyDrag(deltaX: Double, deltaY: Double) {
        isCoasting = false
        let now = Date()
        let deltaLongitude = -deltaX * Self.longitudeSensitivity
        let deltaLatitude = deltaY * Self.latitudeSensitivity

        if let last = lastDragTimestamp {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                velocityLongitude = deltaLongitude / dt
                velocityLatitude = deltaLatitude / dt
            }
        }
        lastDragTimestamp = now

        centerLongitude += deltaLongitude
        centerLatitude = max(-89, min(89, centerLatitude + deltaLatitude))
    }

    /// Call when the drag gesture ends; starts a kinetic coast if the release
    /// velocity is fast enough, otherwise stops immediately.
    func endDrag() {
        lastDragTimestamp = nil
        let speed = (velocityLongitude * velocityLongitude + velocityLatitude * velocityLatitude).squareRoot()
        guard speed >= Self.kineticLaunchSpeed else {
            velocityLongitude = 0
            velocityLatitude = 0
            isCoasting = false
            return
        }
        if speed > Self.kineticMaximumSpeed {
            let ratio = Self.kineticMaximumSpeed / speed
            velocityLongitude *= ratio
            velocityLatitude *= ratio
        }
        isCoasting = true
    }

    /// Advances the kinetic coast by `dt` seconds. Intended to be driven by a
    /// `TimelineView` while `isCoasting` is true.
    func tickCoast(dt: TimeInterval) {
        guard isCoasting else { return }

        centerLongitude += velocityLongitude * dt
        centerLatitude = max(-89, min(89, centerLatitude + velocityLatitude * dt))

        let speed = (velocityLongitude * velocityLongitude + velocityLatitude * velocityLatitude).squareRoot()
        let decayedSpeed = max(0, speed - Self.kineticDeceleration * dt)
        guard decayedSpeed > Self.kineticLaunchSpeed, speed > 0 else {
            isCoasting = false
            velocityLongitude = 0
            velocityLatitude = 0
            return
        }
        let ratio = decayedSpeed / speed
        velocityLongitude *= ratio
        velocityLatitude *= ratio
    }

    func applyZoom(delta: Double) {
        scale = max(Self.minimumScale, min(Self.maximumScale, scale + delta))
    }
}

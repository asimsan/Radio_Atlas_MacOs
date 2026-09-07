import XCTest
@testable import RadioAtlasCore

final class GlobeZoomTests: XCTestCase {
    func testClampHoldsScaleWithinBounds() {
        XCTAssertEqual(GlobeZoom.clamp(scale: 1), 1)
        XCTAssertEqual(GlobeZoom.clamp(scale: 0.1), GlobeZoom.minimumScale)
        XCTAssertEqual(GlobeZoom.clamp(scale: 1000), GlobeZoom.maximumScale)
    }

    /// AppKit reports scroll-up as a negative `scrollingDeltaY`, and scroll-up
    /// zooms in -- the sign flip is easy to invert by accident.
    func testScrollUpZoomsIn() {
        XCTAssertGreaterThan(GlobeZoom.scaleAfterWheel(scale: 1, scrollingDeltaY: -10), 1)
    }

    func testScrollDownZoomsOut() {
        XCTAssertLessThan(GlobeZoom.scaleAfterWheel(scale: 1, scrollingDeltaY: 10), 1)
    }

    /// Zoom is proportional to current scale, so a notch feels the same at
    /// every level rather than crawling when zoomed in.
    func testStepIsProportionalToCurrentScale() {
        let fromOne = GlobeZoom.scaleAfterWheel(scale: 1, scrollingDeltaY: -10) - 1
        let fromFour = GlobeZoom.scaleAfterWheel(scale: 4, scrollingDeltaY: -10) - 4
        XCTAssertEqual(fromFour, fromOne * 4, accuracy: 1e-9)
    }

    func testWheelCannotEscapeBounds() {
        XCTAssertEqual(GlobeZoom.scaleAfterWheel(scale: GlobeZoom.maximumScale, scrollingDeltaY: -10_000),
                       GlobeZoom.maximumScale)
        XCTAssertEqual(GlobeZoom.scaleAfterWheel(scale: GlobeZoom.minimumScale, scrollingDeltaY: 10_000),
                       GlobeZoom.minimumScale)
    }

    func testZeroScrollIsANoOp() {
        XCTAssertEqual(GlobeZoom.scaleAfterWheel(scale: 3, scrollingDeltaY: 0), 3)
    }
}

import XCTest
@testable import RadioAtlasCore

final class AuroraBandConfigTests: XCTestCase {
    func testResolveNilActivityFallsBackToStaticLook() {
        XCTAssertEqual(AuroraBandConfig.resolve(activity: nil), .fallback)
    }

    func testResolveZeroIntensityFallsBackToStaticLook() {
        let quiet = HemisphereActivity(intensity: 0, equatorwardLatitude: nil)
        XCTAssertEqual(AuroraBandConfig.resolve(activity: quiet), .fallback)
    }

    func testStormActivityMovesBandsEquatorwardAndBrightens() {
        let storm = HemisphereActivity(intensity: 1, equatorwardLatitude: 52)
        let config = AuroraBandConfig.resolve(activity: storm)

        XCTAssertEqual(config.innerBand, LatitudeBand(inner: 52, outer: 58))
        XCTAssertEqual(config.outerBand, LatitudeBand(inner: 58, outer: 64))
        XCTAssertEqual(config.amplitude, 5.0, accuracy: 0.0001)
        XCTAssertEqual(config.opacityMultiplier, 1.5, accuracy: 0.0001)
    }

    func testQuietActivityKeepsBandsPolewardAndDim() {
        let quiet = HemisphereActivity(intensity: 0.5, equatorwardLatitude: 72)
        let config = AuroraBandConfig.resolve(activity: quiet)

        XCTAssertEqual(config.innerBand, LatitudeBand(inner: 72, outer: 78))
        XCTAssertEqual(config.outerBand, LatitudeBand(inner: 78, outer: 84))
        XCTAssertEqual(config.amplitude, 3.75, accuracy: 0.0001)
        XCTAssertEqual(config.opacityMultiplier, 1.05, accuracy: 0.0001)
    }

    func testExtentIsClampedToShowableRange() {
        // The clamp bounds the equatorward (inner) edge; the poleward outer
        // edge extends beyond it.
        let extremeStorm = HemisphereActivity(intensity: 1, equatorwardLatitude: 45)
        let extremeQuiet = HemisphereActivity(intensity: 0.5, equatorwardLatitude: 85)

        XCTAssertEqual(AuroraBandConfig.resolve(activity: extremeStorm).innerBand.inner, 50, accuracy: 0.0001)
        XCTAssertEqual(AuroraBandConfig.resolve(activity: extremeQuiet).innerBand.inner, 80, accuracy: 0.0001)
    }

    func testMixedAtHalfwayPointAveragesFields() {
        let storm = AuroraBandConfig.resolve(activity: HemisphereActivity(intensity: 1, equatorwardLatitude: 52))
        let half = storm.mixed(with: .fallback, factor: 0.5)

        XCTAssertEqual(half.innerBand.inner, 56.5, accuracy: 0.0001) // (52 + 61) / 2
        XCTAssertEqual(half.amplitude, (5.0 + 3.5) / 2, accuracy: 0.0001)
        XCTAssertEqual(half.opacityMultiplier, (1.5 + 1.0) / 2, accuracy: 0.0001)
    }

    func testMixedFactorZeroAndOneAreExactEndpoints() {
        let storm = AuroraBandConfig.resolve(activity: HemisphereActivity(intensity: 1, equatorwardLatitude: 52))

        XCTAssertEqual(storm.mixed(with: .fallback, factor: 0), storm)
        XCTAssertEqual(storm.mixed(with: .fallback, factor: 1), .fallback)
    }

    func testMixedClampsFactorOutsideUnitRange() {
        let storm = AuroraBandConfig.resolve(activity: HemisphereActivity(intensity: 1, equatorwardLatitude: 52))

        XCTAssertEqual(storm.mixed(with: .fallback, factor: 2), .fallback)
        XCTAssertEqual(storm.mixed(with: .fallback, factor: -1), storm)
    }
}

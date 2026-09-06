import XCTest
@testable import RadioAtlasCore

final class AuroraActivityReducerTests: XCTestCase {
    private func makeData(north: [OvationPoint], south: [OvationPoint]) -> OvationAuroraData {
        OvationAuroraData(coordinates: north + south)
    }

    private func quietHemisphere(sign: Double) -> [OvationPoint] {
        // Peak 20, significant activity between |lat| 70 and 85.
        (0..<40).map { index in
            let latitude = sign * (70 + Double(index) * 15.0 / 39.0)
            let value = index < 20 ? 20.0 : 10.0 // upper half significant
            return OvationPoint(longitude: 0, latitude: latitude, aurora: value)
        }
    }

    func testQuietHemisphereYieldsHighExtentAndModerateIntensity() {
        let activity = AuroraActivityReducer.derive(
            from: makeData(north: quietHemisphere(sign: 1), south: [])
        )

        // 10th percentile of significant |lat|s: significant covers 70–85,
        // its 10th percentile is ≈71.2.
        XCTAssertEqual(activity.north.equatorwardLatitude ?? 0, 71.2, accuracy: 0.5)
        // Values are 20 (half) and 10 (half), all above the 10 threshold →
        // mean/peak = 0.75 → intensity (0.75 - 0.5) * 2 = 0.5.
        XCTAssertEqual(activity.north.intensity, 0.5, accuracy: 0.001)
    }

    func testStormyHemisphereReachesMuchFurtherFromThePole() {
        let storm: [OvationPoint] = (0..<40).map { index in
            let latitude = 50 + Double(index) * 15.0 / 39.0
            return OvationPoint(longitude: 0, latitude: latitude, aurora: index < 20 ? 120 : 60)
        }
        let activity = AuroraActivityReducer.derive(from: makeData(north: storm, south: []))

        // Same shape as the quiet feed but centered at 50–65 instead of 70–85.
        XCTAssertEqual(activity.north.equatorwardLatitude ?? 0, 51.2, accuracy: 0.5)
        // Same value mix as the quiet feed → intensity 0.5.
        XCTAssertEqual(activity.north.intensity, 0.5, accuracy: 0.001)
    }

    func testMixedSignificantValuesProduceSubPeakIntensity() {
        // Half the significant points at peak, half at the threshold → mean
        // ratio 0.75 → intensity (0.75 - 0.5) * 2 = 0.5.
        let points: [OvationPoint] = (0..<40).map { index in
            let latitude = 70 + Double(index) * 10.0 / 39.0
            let value: Double = index < 10 ? 40 : (index < 20 ? 20 : 5)
            return OvationPoint(longitude: 0, latitude: latitude, aurora: value)
        }
        let activity = AuroraActivityReducer.derive(from: makeData(north: points, south: []))

        XCTAssertEqual(activity.north.intensity, 0.5, accuracy: 0.001)
    }

    func testHemispheresAreIndependent() {
        let activity = AuroraActivityReducer.derive(
            from: makeData(north: quietHemisphere(sign: 1), south: quietHemisphere(sign: -1).map {
                // +10 shifts -70…-85 toward the equator: -60…-75.
                OvationPoint(longitude: $0.longitude, latitude: $0.latitude + 10, aurora: $0.aurora)
            })
        )

        // South feed shifted 10° closer to the equator (latitudes 60–75).
        XCTAssertEqual(activity.north.equatorwardLatitude ?? 0, 71.2, accuracy: 0.5)
        XCTAssertEqual(activity.south.equatorwardLatitude ?? 0, 61.2, accuracy: 0.5)
    }

    func testEmptyHemisphereYieldsZeroIntensityAndNilExtent() {
        let activity = AuroraActivityReducer.derive(from: makeData(north: [], south: []))

        XCTAssertEqual(activity.north.intensity, 0)
        XCTAssertNil(activity.north.equatorwardLatitude)
        XCTAssertEqual(activity.south.intensity, 0)
        XCTAssertNil(activity.south.equatorwardLatitude)
    }

    func testStrayLowLatitudePointDoesNotDominateExtent() {
        // 40 significant points at 70–85 plus one stray at 45: the 10th
        // percentile (robust measure) must ignore the stray.
        var points = quietHemisphere(sign: 1)
        points.append(OvationPoint(longitude: 0, latitude: 45, aurora: 20))
        let activity = AuroraActivityReducer.derive(from: makeData(north: points, south: []))

        XCTAssertEqual(activity.north.equatorwardLatitude ?? 0, 70.75, accuracy: 0.5)
    }
}

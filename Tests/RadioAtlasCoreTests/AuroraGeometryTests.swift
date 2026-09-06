import XCTest
@testable import RadioAtlasCore

final class AuroraGeometryTests: XCTestCase {
    // MARK: - edgeLatitude

    func testEdgeLatitudeIsBaseWhenAmplitudeIsZero() {
        XCTAssertEqual(
            AuroraGeometry.edgeLatitude(base: 66, amplitude: 0, waveCount: 3, longitude: 137, phase: 0.9),
            66,
            accuracy: 0.0001
        )
    }

    func testEdgeLatitudePeaksAtTheWaveCrest() {
        // waveCount 3 at longitude 30°: 3·(π/6) = π/2 → sin = 1.
        XCTAssertEqual(
            AuroraGeometry.edgeLatitude(base: 66, amplitude: 4, waveCount: 3, longitude: 30, phase: 0),
            70,
            accuracy: 0.0001
        )
    }

    func testEdgeLatitudePhaseShiftsTheWave() {
        // Same point, phase π flips the sine.
        XCTAssertEqual(
            AuroraGeometry.edgeLatitude(base: 66, amplitude: 4, waveCount: 3, longitude: 30, phase: .pi),
            62,
            accuracy: 0.0001
        )
    }

    func testEdgeLatitudeIsPeriodicOver360Degrees() {
        XCTAssertEqual(
            AuroraGeometry.edgeLatitude(base: 66, amplitude: 4, waveCount: 3, longitude: 30, phase: 0),
            AuroraGeometry.edgeLatitude(base: 66, amplitude: 4, waveCount: 3, longitude: 390, phase: 0),
            accuracy: 0.0001
        )
    }

    // MARK: - ring

    func testRingClosesAndHoldsLatitude() {
        let ring = AuroraGeometry.ring(pole: .north, latitude: 70, samples: 72)

        XCTAssertEqual(ring.count, 73)
        XCTAssertEqual(ring.first, ring.last)
        XCTAssertTrue(ring.dropLast().allSatisfy { $0.latitude == 70 })
    }

    func testRingStepsAroundFull360Degrees() {
        let ring = AuroraGeometry.ring(pole: .north, latitude: 70, samples: 8)

        let longitudes = ring.map(\.longitude)
        XCTAssertEqual(longitudes, [-180, -135, -90, -45, 0, 45, 90, 135, -180])
    }

    func testSouthPoleRingNegatesLatitude() {
        let ring = AuroraGeometry.ring(pole: .south, latitude: 70, samples: 8)

        XCTAssertTrue(ring.dropLast().allSatisfy { $0.latitude == -70 })
    }

    // MARK: - wavyRing

    func testWavyRingClosesAndStaysOnPoleSide() {
        let ring = AuroraGeometry.wavyRing(pole: .south, base: 66, amplitude: 4, waveCount: 3, phase: 0.5, samples: 72)

        XCTAssertEqual(ring.count, 73)
        XCTAssertEqual(ring.first, ring.last)
        XCTAssertTrue(ring.dropLast().allSatisfy { $0.latitude < 0 })
    }

    func testWavyRingNorthPoleHasPositiveLatitudes() {
        let ring = AuroraGeometry.wavyRing(pole: .north, base: 66, amplitude: 4, waveCount: 3, phase: 0, samples: 8)

        XCTAssertTrue(ring.dropLast().allSatisfy { $0.latitude > 0 })
    }

    func testWavyRingCrestsAtTheWavePeak() {
        let ring = AuroraGeometry.wavyRing(pole: .north, base: 66, amplitude: 4, waveCount: 3, phase: 0, samples: 12)

        // Longitude 30° is a crest (see testEdgeLatitudePeaksAtTheWaveCrest).
        let crest = ring.first { $0.longitude == 30 }
        XCTAssertEqual(crest?.latitude ?? 0, 70, accuracy: 0.0001)
    }
}

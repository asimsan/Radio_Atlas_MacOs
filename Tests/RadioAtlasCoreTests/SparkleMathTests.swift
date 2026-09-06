import XCTest
@testable import RadioAtlasCore

final class SparkleMathTests: XCTestCase {
    // MARK: - hash

    func testHashIsDeterministicAndInUnitRange() {
        for index in 0..<100 {
            let first = SparkleMath.hash(index)
            let second = SparkleMath.hash(index)
            XCTAssertEqual(first, second)
            XCTAssertGreaterThanOrEqual(first, 0)
            XCTAssertLessThan(first, 1)
        }
    }

    func testHashDiffersAcrossRayIndices() {
        let values = (0..<12).map { SparkleMath.hash($0) }
        XCTAssertEqual(Set(values).count, 12)
    }

    // MARK: - twinkleOpacity

    func testTwinkleOpacityStaysInRangeForAllPhases() {
        for index in 0..<12 {
            for step in 0..<200 {
                let phase = Double(step) * 0.1
                let opacity = SparkleMath.twinkleOpacity(index: index, phase: phase)
                XCTAssertGreaterThanOrEqual(opacity, 0.3)
                XCTAssertLessThanOrEqual(opacity, 1.0)
            }
        }
    }

    func testTwinkleOpacityIsPeriodic() {
        XCTAssertEqual(
            SparkleMath.twinkleOpacity(index: 3, phase: 0.7),
            SparkleMath.twinkleOpacity(index: 3, phase: 0.7 + 2 * .pi),
            accuracy: 0.0001
        )
    }

    func testTwinkleOpacityDiffersBetweenIndicesAtSamePhase() {
        XCTAssertNotEqual(
            SparkleMath.twinkleOpacity(index: 0, phase: 1.0),
            SparkleMath.twinkleOpacity(index: 5, phase: 1.0)
        )
    }

    // MARK: - flareEnvelope

    func testFlareEnvelopeIsMostlyQuietAndPeaksSharply() {
        // Quiet at the cycle start, full flare at the sine peak.
        XCTAssertEqual(SparkleMath.flareEnvelope(phase: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(SparkleMath.flareEnvelope(phase: .pi / 2), 1, accuracy: 0.0001)
        // Sharpness: at a quarter of the way to the peak it's still tiny.
        XCTAssertLessThan(SparkleMath.flareEnvelope(phase: .pi / 8), 0.01)
    }

    func testFlareEnvelopeStaysInUnitRange() {
        for step in 0..<200 {
            let value = SparkleMath.flareEnvelope(phase: Double(step) * 0.1)
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }
}

import XCTest
@testable import RadioAtlasCore

final class CoreMarkerTests: XCTestCase {
    func testMarkerName() {
        XCTAssertEqual(CoreMarker.name, "RadioAtlasCore")
    }
}

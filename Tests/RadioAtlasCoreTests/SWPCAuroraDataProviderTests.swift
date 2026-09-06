import XCTest
@testable import RadioAtlasCore

final class SWPCAuroraDataProviderTests: XCTestCase {
    func testFetchDecodesOvationFeed() async throws {
        StubURLProtocol.responseData = """
        {"coordinates": [[0, -90, 4], [0, 60, 12]]}
        """.data(using: .utf8)!
        let provider = SWPCAuroraDataProvider(
            session: StubURLProtocol.makeSession(),
            url: URL(string: "https://services.test/ovation.json")!
        )

        let data = try await provider.fetchAuroraData()

        XCTAssertEqual(data.coordinates.count, 2)
        XCTAssertEqual(data.coordinates[1], OvationPoint(longitude: 0, latitude: 60, aurora: 12))
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.absoluteString, "https://services.test/ovation.json")
    }

    func testFetchPropagatesServerErrors() async {
        StubURLProtocol.responseError = URLError(.cannotConnectToHost)
        let provider = SWPCAuroraDataProvider(
            session: StubURLProtocol.makeSession(),
            url: URL(string: "https://services.test/ovation.json")!
        )

        do {
            _ = try await provider.fetchAuroraData()
            XCTFail("expected an error")
        } catch {
            // Expected: the caller falls back to the static aurora look.
        }
    }
}

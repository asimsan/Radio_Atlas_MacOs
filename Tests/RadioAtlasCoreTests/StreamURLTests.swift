import XCTest
@testable import RadioAtlasCore

final class StreamURLTests: XCTestCase {
    /// The case this exists for: Radio Browser lists Butwal FM on a port that
    /// only speaks TLS, so the plain-http request is refused. Browsers hide it
    /// by auto-upgrading; AVPlayer does not.
    func testUpgradesCleartextHTTPPreservingPortAndAwkwardPath() throws {
        let url = try XCTUnwrap(URL(string: "http://streaming.softnep.net:10994/;stream.nsv"))
        let upgraded = try XCTUnwrap(StreamURL.tlsUpgraded(url))
        XCTAssertEqual(upgraded.absoluteString, "https://streaming.softnep.net:10994/;stream.nsv")
    }

    func testPreservesQueryAndPath() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/live/stream.mp3?token=abc&x=1"))
        let upgraded = try XCTUnwrap(StreamURL.tlsUpgraded(url))
        XCTAssertEqual(upgraded.absoluteString, "https://example.com/live/stream.mp3?token=abc&x=1")
    }

    /// Nothing to upgrade, and returning a value would let the retry run twice.
    func testReturnsNilForURLsAlreadyOverTLS() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/s"))
        XCTAssertNil(StreamURL.tlsUpgraded(url))
    }

    func testReturnsNilForNonHTTPSchemes() throws {
        for raw in ["rtsp://example.com/s", "file:///tmp/a.mp3", "mms://example.com/s"] {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertNil(StreamURL.tlsUpgraded(url), raw)
        }
    }

    func testSchemeMatchIsCaseInsensitive() throws {
        let url = try XCTUnwrap(URL(string: "HTTP://example.com/s"))
        XCTAssertEqual(StreamURL.tlsUpgraded(url)?.scheme, "https")
    }
}

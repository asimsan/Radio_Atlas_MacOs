import XCTest
@testable import RadioAtlasCore

final class FakeStreamPlayer: StreamPlaying {
    var onStatusChange: ((PlaybackStatus) -> Void)?
    private(set) var playedURLs: [URL] = []
    private(set) var pauseCallCount = 0
    private(set) var lastOutputDeviceUID: String??

    func play(url: URL) { playedURLs.append(url) }
    func pause() { pauseCallCount += 1 }
    func stop() {}
    func setVolume(_ volume: Float) {}
    func setOutputDeviceUID(_ uid: String?) { lastOutputDeviceUID = uid }
}

final class PlaybackControllerTests: XCTestCase {
    private func station(_ id: String) -> Station {
        Station(id: id, name: id, streamURL: URL(string: "https://s.example/\(id).mp3")!,
                homepage: nil, faviconURL: nil, tags: [], countryCode: "US", country: "United States",
                latitude: nil, longitude: nil, votes: 0, clickCount: 0, bitrateKbps: 128)
    }

    func testSetQueueStartsPlaybackAtGivenIndex() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let stations = [station("a"), station("b"), station("c")]

        controller.setQueue(stations, startAt: 1)

        XCTAssertEqual(player.playedURLs, [stations[1].streamURL])
        XCTAssertEqual(controller.currentIndex, 1)
    }

    func testNextWrapsAroundToStartOfQueue() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let stations = [station("a"), station("b")]
        controller.setQueue(stations, startAt: 1)

        controller.next()

        XCTAssertEqual(controller.currentIndex, 0)
        XCTAssertEqual(player.playedURLs.last, stations[0].streamURL)
    }

    func testPreviousWrapsAroundToEndOfQueue() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let stations = [station("a"), station("b")]
        controller.setQueue(stations, startAt: 0)

        controller.previous()

        XCTAssertEqual(controller.currentIndex, 1)
        XCTAssertEqual(player.playedURLs.last, stations[1].streamURL)
    }

    func testSetOutputDeviceForwardsToPlayer() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)

        controller.setOutputDevice(uid: "airplay-1")

        XCTAssertEqual(player.lastOutputDeviceUID, "airplay-1")
    }
}

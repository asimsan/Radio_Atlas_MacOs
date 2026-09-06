import XCTest
@testable import RadioAtlasCore

final class FakeStreamPlayer: StreamPlaying {
    var onStatusChange: ((PlaybackStatus) -> Void)?
    private(set) var playedStations: [Station] = []
    private(set) var pauseCallCount = 0
    private(set) var lastOutputDeviceUID: String??

    func play(station: Station) { playedStations.append(station) }
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

        XCTAssertEqual(player.playedStations.map(\.streamURL), [stations[1].streamURL])
        XCTAssertEqual(controller.currentIndex, 1)
    }

    func testNextWrapsAroundToStartOfQueue() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let stations = [station("a"), station("b")]
        controller.setQueue(stations, startAt: 1)

        controller.next()

        XCTAssertEqual(controller.currentIndex, 0)
        XCTAssertEqual(player.playedStations.last?.streamURL, stations[0].streamURL)
    }

    func testPreviousWrapsAroundToEndOfQueue() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let stations = [station("a"), station("b")]
        controller.setQueue(stations, startAt: 0)

        controller.previous()

        XCTAssertEqual(controller.currentIndex, 1)
        XCTAssertEqual(player.playedStations.last?.streamURL, stations[1].streamURL)
    }

    func testSetOutputDeviceForwardsToPlayer() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)

        controller.setOutputDevice(uid: "airplay-1")

        XCTAssertEqual(player.lastOutputDeviceUID, "airplay-1")
    }

    func testToggleMuteSetsVolumeToZeroThenRestoresIt() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        controller.volume = 0.8

        controller.toggleMute()
        XCTAssertTrue(controller.isMuted)
        XCTAssertEqual(controller.volume, 0)

        controller.toggleMute()
        XCTAssertFalse(controller.isMuted)
        XCTAssertEqual(controller.volume, 0.8)
    }

    func testSettingVolumeDirectlyWhileMutedClearsMuteAndKeepsNewValue() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        controller.volume = 0.8
        controller.toggleMute()
        XCTAssertTrue(controller.isMuted)
        XCTAssertEqual(controller.volume, 0)

        // Simulates dragging the player bar's volume slider directly while
        // muted, bypassing toggleMute().
        controller.volume = 0.3

        XCTAssertFalse(controller.isMuted)
        XCTAssertEqual(controller.volume, 0.3)

        // Toggling mute again must not resurrect the stale pre-mute volume
        // (0.8) — it should mute from the slider's current value (0.3).
        controller.toggleMute()
        XCTAssertTrue(controller.isMuted)
        XCTAssertEqual(controller.volume, 0)

        controller.toggleMute()
        XCTAssertFalse(controller.isMuted)
        XCTAssertEqual(controller.volume, 0.3)
    }

    func testMutingFromUnmutedStillEndsMutedAtZeroVolume() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        controller.volume = 0.6
        XCTAssertFalse(controller.isMuted)

        controller.toggleMute()

        XCTAssertTrue(controller.isMuted)
        XCTAssertEqual(controller.volume, 0)
    }

    // MARK: - pause

    func testPauseStopsAPlayingStream() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let station = station("a")
        player.onStatusChange?(.playing(station))

        controller.pause()

        XCTAssertEqual(player.pauseCallCount, 1)
        // Status transitions are driven by the player's callback, not by
        // pause() itself.
        if case .playing = controller.status {} else {
            XCTFail("expected playing status")
        }
    }

    func testPauseDoesNothingWhenNotPlaying() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)

        controller.pause()

        XCTAssertEqual(player.pauseCallCount, 0)
    }
}

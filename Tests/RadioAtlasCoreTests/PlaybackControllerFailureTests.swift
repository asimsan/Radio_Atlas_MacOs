import XCTest
@testable import RadioAtlasCore

final class PlaybackControllerFailureTests: XCTestCase {
    private func station(_ id: String) -> Station {
        Station(id: id, name: id, streamURL: URL(string: "https://s.example/\(id).mp3")!,
                homepage: nil, faviconURL: nil, tags: [], countryCode: "US", country: "United States",
                latitude: nil, longitude: nil, votes: 0, clickCount: 0, bitrateKbps: 128)
    }

    func testTogglePlayPauseRetriesAFailedStationInsteadOfAdvancing() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let target = station("a")
        controller.setQueue([target], startAt: 0)

        player.onStatusChange?(.failed(target, message: "network error"))
        controller.togglePlayPause()

        XCTAssertEqual(player.playedStations.last, target, "retrying a failed station must replay it, not silently skip to another one")
        XCTAssertEqual(controller.currentIndex, 0, "a failed station must stay selected, matching the original's no-auto-advance behavior")
    }

    func testCurrentStationReturnsTheStationForEveryNonIdleStatus() {
        let player = FakeStreamPlayer()
        let controller = PlaybackController(player: player)
        let target = station("a")
        XCTAssertNil(controller.currentStation)

        controller.setQueue([target], startAt: 0)
        player.onStatusChange?(.paused(target))
        XCTAssertEqual(controller.currentStation, target)

        player.onStatusChange?(.failed(target, message: "x"))
        XCTAssertEqual(controller.currentStation, target)
    }
}

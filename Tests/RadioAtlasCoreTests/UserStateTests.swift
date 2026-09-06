import XCTest
@testable import RadioAtlasCore

/// Unit tests for `UserState`'s pure mutation logic. This logic used to live
/// inline in `PanelViewModel` (the `RadioAtlas` app target, which this test
/// target cannot import), so it had zero test coverage. Moved onto `UserState`
/// itself specifically so it's testable here.
final class UserStateTests: XCTestCase {
    // MARK: - recordPlay

    func testRecordPlayPrependsStationID() {
        var state = UserState.empty
        state.recordPlay("a")
        XCTAssertEqual(state.recentStationIDs, ["a"])

        state.recordPlay("b")
        XCTAssertEqual(state.recentStationIDs, ["b", "a"])
    }

    func testRecordPlayDedupesPriorOccurrenceInsteadOfCreatingADuplicate() {
        var state = UserState.empty
        state.recordPlay("a")
        state.recordPlay("b")
        state.recordPlay("c")

        // Replaying "a" should move it to the front, not add a second "a".
        state.recordPlay("a")

        XCTAssertEqual(state.recentStationIDs, ["a", "c", "b"])
        XCTAssertEqual(state.recentStationIDs.filter { $0 == "a" }.count, 1)
    }

    func testRecordPlayCapsAt50Entries() {
        var state = UserState.empty
        for i in 0..<60 {
            state.recordPlay("station-\(i)")
        }

        XCTAssertEqual(state.recentStationIDs.count, 50)
        // Most recently played stay at the front.
        XCTAssertEqual(state.recentStationIDs.first, "station-59")
        XCTAssertEqual(state.recentStationIDs.last, "station-10")
    }

    // MARK: - toggleFavorite

    func testToggleFavoriteAddsThenRemoves() {
        var state = UserState.empty
        XCTAssertFalse(state.favoriteStationIDs.contains("a"))

        state.toggleFavorite("a")
        XCTAssertTrue(state.favoriteStationIDs.contains("a"))

        state.toggleFavorite("a")
        XCTAssertFalse(state.favoriteStationIDs.contains("a"))
    }

    // MARK: - clearRecents

    func testClearRecentsEmptiesListeningHistory() {
        var state = UserState.empty
        state.recordPlay("a")
        state.recordPlay("b")
        XCTAssertEqual(state.recentStationIDs, ["b", "a"])

        state.clearRecents()

        XCTAssertTrue(state.recentStationIDs.isEmpty)
    }

    func testClearRecentsLeavesFavoritesUntouched() {
        var state = UserState.empty
        state.toggleFavorite("a")
        state.recordPlay("a")

        state.clearRecents()

        XCTAssertEqual(state.favoriteStationIDs, ["a"])
        XCTAssertTrue(state.recentStationIDs.isEmpty)
    }
}

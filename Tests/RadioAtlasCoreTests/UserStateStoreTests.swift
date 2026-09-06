import XCTest
@testable import RadioAtlasCore

final class UserStateStoreTests: XCTestCase {
    private func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testLoadReturnsEmptyStateWhenNoFileExists() {
        let store = UserStateStore(directory: makeTempDirectory())
        XCTAssertEqual(store.load(), .empty)
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = UserStateStore(directory: makeTempDirectory())
        var state = UserState.empty
        state.favoriteStationIDs = ["a1", "b2"]
        state.recentStationIDs = ["b2", "a1"]
        state.volume = 0.6
        state.outputDeviceUID = "device-uid-1"

        try store.save(state)

        XCTAssertEqual(store.load(), state)
    }

    func testLoadIgnoresCorruptFileWithoutOverwritingIt() throws {
        let dir = makeTempDirectory()
        let store = UserStateStore(directory: dir)
        let fileURL = dir.appendingPathComponent("state.json")
        let garbage = Data("not json".utf8)
        try garbage.write(to: fileURL)

        let loaded = store.load()

        XCTAssertEqual(loaded, .empty)
        XCTAssertEqual(try Data(contentsOf: fileURL), garbage, "corrupt state file must be left untouched, not silently overwritten")
    }
}

import Foundation

public final class UserStateStore {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("state.json")
    }

    /// Returns `.empty` if no file exists or the file can't be parsed.
    /// A corrupt file is left on disk untouched — callers should not lose
    /// data due to a save() overwriting a file that failed to parse.
    public func load() -> UserState {
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        guard let state = try? JSONDecoder().decode(UserState.self, from: data) else { return .empty }
        return state
    }

    public func save(_ state: UserState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}

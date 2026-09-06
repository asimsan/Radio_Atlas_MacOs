import Foundation

public struct UserState: Codable, Equatable {
    public var favoriteStationIDs: Set<String>
    public var recentStationIDs: [String]
    public var volume: Float
    public var outputDeviceUID: String?

    public static let empty = UserState(
        favoriteStationIDs: [],
        recentStationIDs: [],
        volume: 1.0,
        outputDeviceUID: nil
    )

    /// Records a play of `stationID` at the front of `recentStationIDs`,
    /// removing any prior occurrence first so the same station can't appear
    /// twice (which would otherwise produce duplicate SwiftUI `ForEach`
    /// identities in the Recent tab), and caps the list at 50 entries.
    public mutating func recordPlay(_ stationID: String) {
        recentStationIDs = ([stationID] + recentStationIDs.filter { $0 != stationID }).prefix(50).map { $0 }
    }

    /// Toggles membership of `stationID` in `favoriteStationIDs`.
    public mutating func toggleFavorite(_ stationID: String) {
        if favoriteStationIDs.contains(stationID) {
            favoriteStationIDs.remove(stationID)
        } else {
            favoriteStationIDs.insert(stationID)
        }
    }

    /// Empties the listening history (the Recent tab's source). Favorites
    /// are untouched.
    public mutating func clearRecents() {
        recentStationIDs.removeAll()
    }
}

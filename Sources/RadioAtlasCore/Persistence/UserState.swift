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
}

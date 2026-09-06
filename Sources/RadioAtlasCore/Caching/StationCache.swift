import Foundation

public final class StationCache {
    private struct CachedStations: Codable {
        let stations: [Station]
        let fetchedAt: Date
    }

    private let fileURL: URL
    private let ttl: TimeInterval

    public init(directory: URL, filename: String, ttl: TimeInterval = 6 * 3600) {
        self.fileURL = directory.appendingPathComponent(filename)
        self.ttl = ttl
    }

    public func read(now: Date = Date()) -> [Station]? {
        guard let data = try? Data(contentsOf: fileURL),
              let cached = try? JSONDecoder().decode(CachedStations.self, from: data),
              now.timeIntervalSince(cached.fetchedAt) < ttl
        else { return nil }
        return cached.stations
    }

    public func write(_ stations: [Station], now: Date = Date()) throws {
        let cached = CachedStations(stations: stations, fetchedAt: now)
        let data = try JSONEncoder().encode(cached)
        try data.write(to: fileURL, options: .atomic)
    }
}

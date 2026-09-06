import Foundation

public final class RadioBrowserClient {
    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared, baseURL: URL = URL(string: "https://de1.api.radio-browser.info")!) {
        self.session = session
        self.baseURL = baseURL
    }

    public func topStations(limit: Int = 500) async throws -> [Station] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/json/stations"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await fetchStations(url: components.url!)
    }

    public func searchStations(query: String, limit: Int = 100) async throws -> [Station] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/json/stations/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await fetchStations(url: components.url!)
    }

    public func stationsByCountryCode(_ code: String) async throws -> [Station] {
        let url = baseURL.appendingPathComponent("/json/stations/bycountrycodeexact/\(code)")
        return try await fetchStations(url: url)
    }

    public func registerClick(stationID: String) async {
        let url = baseURL.appendingPathComponent("/json/url/\(stationID)")
        _ = try? await session.data(from: url)
    }

    private func fetchStations(url: URL) async throws -> [Station] {
        let (data, _) = try await session.data(from: url)
        let raw = try JSONDecoder().decode([RawStation].self, from: data)
        return raw.compactMap(Station.init(raw:))
    }
}

import Foundation

public final class RadioBrowserClient {
    /// Radio Browser is a free, community-run service, and its API guidance
    /// asks clients to identify themselves so its operators can see who is
    /// using it and contact them about misbehaviour. URLSession's default
    /// agent says nothing, so every request carries this instead.
    public static let userAgent = "RadioAtlas/0.1.0 (macOS; +https://github.com/asimsan/Radio_Atlas_MacOs)"

    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared, baseURL: URL = URL(string: "https://de1.api.radio-browser.info")!) {
        self.session = session
        self.baseURL = baseURL
    }

    /// The world list's depth. Measured against the live directory (57,911
    /// stations): 500 covers only 56 countries and yields 134 globe markers,
    /// because just ~26% of stations carry coordinates. 5,000 reaches 161
    /// countries and ~1,260 markers for a 5.7MB background refresh, and even
    /// the last entry at that depth has real play counts rather than being
    /// dead weight. `hidebroken` is deliberately not sent: ordering by
    /// clickcount already keeps broken streams out of this range, and it was
    /// measured to add nothing here.
    public static let defaultTopStationsLimit = 5_000

    public func topStations(limit: Int = RadioBrowserClient.defaultTopStationsLimit) async throws -> [Station] {
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
        var components = URLComponents(url: baseURL.appendingPathComponent("/json/stations/bycountrycodeexact/\(code)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true")
        ]
        return try await fetchStations(url: components.url!)
    }

    public func registerClick(stationID: String) async {
        let url = baseURL.appendingPathComponent("/json/url/\(stationID)")
        _ = try? await session.data(for: request(for: url))
    }

    private func fetchStations(url: URL) async throws -> [Station] {
        let (data, _) = try await session.data(for: request(for: url))
        let raw = try JSONDecoder().decode([RawStation].self, from: data)
        return raw.compactMap(Station.init(raw:))
    }

    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}

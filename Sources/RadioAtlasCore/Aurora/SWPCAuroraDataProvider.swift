import Foundation

/// Fetches aurora forecast data, injectable so consumers can stub it in tests.
public protocol AuroraDataProviding {
    func fetchAuroraData() async throws -> OvationAuroraData
}

/// Downloads the NOAA Space Weather Prediction Center's OVATION aurora
/// forecast (`ovation_aurora_latest.json`, refreshed by SWPC every few
/// minutes).
public final class SWPCAuroraDataProvider: AuroraDataProviding {
    private let session: URLSession
    private let url: URL

    public init(
        session: URLSession = .shared,
        url: URL = URL(string: "https://services.swpc.noaa.gov/json/ovation_aurora_latest.json")!
    ) {
        self.session = session
        self.url = url
    }

    public func fetchAuroraData() async throws -> OvationAuroraData {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(OvationAuroraData.self, from: data)
    }
}

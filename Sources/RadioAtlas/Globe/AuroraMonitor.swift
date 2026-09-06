import Combine
import Foundation
import RadioAtlasCore

/// Periodically refreshes the NOAA SWPC OVATION aurora forecast and publishes
/// the reduced activity summary. A failed fetch clears `activity`, and the
/// globe falls back to its static aurora look until the next refresh.
@MainActor
final class AuroraMonitor: ObservableObject {
    @Published private(set) var activity: AuroraActivity?

    private let provider: any AuroraDataProviding
    private let refreshInterval: TimeInterval
    private var fetchTask: Task<Void, Never>?

    init(
        provider: any AuroraDataProviding = SWPCAuroraDataProvider(),
        refreshInterval: TimeInterval = 300
    ) {
        self.provider = provider
        self.refreshInterval = refreshInterval
    }

    /// Fetches immediately, then every `refreshInterval` seconds, until the
    /// task is cancelled. Safe to call once per monitor.
    func start() {
        guard fetchTask == nil else { return }
        fetchTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                if let data = try? await self.provider.fetchAuroraData() {
                    self.activity = AuroraActivityReducer.derive(from: data)
                } else {
                    self.activity = nil
                }
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
            }
        }
    }
}

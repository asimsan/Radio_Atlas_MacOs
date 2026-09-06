import Combine
import Foundation

/// The slice of the Radio Browser API the search pipeline needs, extracted so
/// the coordinator's state machine is testable with a stub directory.
public protocol StationDirectoryProviding {
    func topStations(limit: Int) async throws -> [Station]
    func stationsByCountryCode(_ code: String) async throws -> [Station]
}

extension RadioBrowserClient: StationDirectoryProviding {}

/// Owns the World-tab list and country-browse state, so the search field and
/// the globe share one "country mode" instead of two disconnected mechanisms.
///
/// - Non-country queries filter the base (top-stations) list locally, instantly.
/// - A query that names a country (see `CountryMatcher`) switches to country
///   mode and fetches that country's full station list, debounced so typing
///   "germany" doesn't fire a request per keystroke, with stale responses
///   discarded.
/// - Clearing the query exits country mode only when it was entered via the
///   search field; a globe-click browse survives until the user types.
@MainActor
public final class StationSearchCoordinator: ObservableObject {
    /// The list the World tab displays — either the locally filtered base
    /// list or the active country's full station list.
    @Published public private(set) var list: [Station] = []
    @Published public private(set) var countryCode: String?
    @Published public private(set) var countryName: String?
    @Published public private(set) var isLoadingCountry = false
    @Published public private(set) var countryError: String?

    private enum CountryModeOrigin { case search, globe }

    private let directory: any StationDirectoryProviding
    private let regionCodes: Set<String>
    private let debounceInterval: TimeInterval

    private var baseStations: [Station] = []
    private var origin: CountryModeOrigin = .search
    private var searchTask: Task<Void, Never>?
    private var fetchGeneration = 0
    private var lastFetchedCode: String?

    public init(
        directory: any StationDirectoryProviding,
        regionCodes: Set<String> = [],
        debounceInterval: TimeInterval = 0.3
    ) {
        self.directory = directory
        self.regionCodes = regionCodes
        self.debounceInterval = debounceInterval
    }

    /// Replaces the base (top-stations) list. Never clobbers an active
    /// country browse — that list is owned by country mode.
    public func setBaseStations(_ stations: [Station]) {
        baseStations = stations
        guard countryCode == nil else { return }
        list = stations
    }

    public func setQuery(_ query: String) {
        searchTask?.cancel()
        fetchGeneration += 1
        isLoadingCountry = false

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            // An empty query only exits country mode that typing entered —
            // a globe-click browse persists until the user types or exits it.
            if origin == .search, countryCode != nil {
                exitCountryMode()
            }
            return
        }

        guard let match = CountryMatcher.match(trimmed, stations: baseStations, regionCodes: regionCodes) else {
            exitCountryMode()
            list = StationFilter.filter(baseStations, query: trimmed)
            return
        }

        origin = .search
        countryCode = match.isoCode
        countryName = match.name
        isLoadingCountry = true

        // Typing more of the same country's name shouldn't re-hit the API.
        guard match.isoCode != lastFetchedCode else { return }

        let generation = fetchGeneration
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self.performFetch(code: match.isoCode, name: match.name, generation: generation)
        }
    }

    /// Globe-click path: enters country mode directly (no debounce — the user
    /// made one deliberate click, same as today's `browseCountry`).
    public func browseCountry(code: String, name: String?) {
        searchTask?.cancel()
        fetchGeneration += 1
        origin = .globe
        countryCode = code
        countryName = name ?? code
        let generation = fetchGeneration
        Task { [weak self] in await self?.performFetch(code: code, name: name ?? code, generation: generation) }
    }

    public func exitCountryMode() {
        searchTask?.cancel()
        fetchGeneration += 1
        countryCode = nil
        countryName = nil
        isLoadingCountry = false
        countryError = nil
        lastFetchedCode = nil
        list = baseStations
    }

    private func performFetch(code: String, name: String, generation: Int) async {
        isLoadingCountry = true
        countryError = nil
        do {
            let result = try await directory.stationsByCountryCode(code)
            guard generation == fetchGeneration, countryCode == code else { return }
            list = result
            lastFetchedCode = code
            isLoadingCountry = false
        } catch {
            guard generation == fetchGeneration, countryCode == code else { return }
            countryError = "Couldn't load stations for \(name): \(error.localizedDescription)"
            isLoadingCountry = false
        }
    }
}

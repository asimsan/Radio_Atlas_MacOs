import Combine
import Foundation
import RadioAtlasCore

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var stations: [Station] = []
    @Published var searchQuery: String = "" {
        didSet { filteredStations = StationFilter.filter(stations, query: searchQuery) }
    }
    @Published var filteredStations: [Station] = []

    let playbackController: PlaybackController
    private(set) var countryLookup: CountryLookup?
    private(set) var countryRegions: [CountryRegion] = []

    private let client = RadioBrowserClient()
    private let cache: StationCache
    private let stateStore: UserStateStore
    private var userState: UserState
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RadioAtlas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        cache = StationCache(directory: appSupport, filename: "top-stations.json")
        stateStore = UserStateStore(directory: appSupport)
        userState = stateStore.load()
        playbackController = PlaybackController(player: AVPlayerStreamPlayer())
        playbackController.volume = userState.volume

        // ObservableObject does NOT automatically propagate a nested object's
        // changes to views observing the parent. SidebarView and PlayerBarView
        // (Steps 10/11) observe `viewModel`, not `playbackController` directly,
        // so without forwarding this, they would never re-render when playback
        // status changes (e.g. .idle -> .playing after tapping a station).
        playbackController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if let lookup = try? CountryLookup.loadBundled() {
            countryLookup = lookup
            countryRegions = lookup.allRegions()
        }
    }

    func loadStations() async {
        if let cached = cache.read() {
            stations = cached
            filteredStations = StationFilter.filter(cached, query: searchQuery)
        }
        if let fresh = try? await client.topStations() {
            stations = fresh
            filteredStations = StationFilter.filter(fresh, query: searchQuery)
            try? cache.write(fresh)
        }
    }

    func play(_ station: Station) {
        guard let index = filteredStations.firstIndex(of: station) else { return }
        playbackController.setQueue(filteredStations, startAt: index)
        userState.recentStationIDs = ([station.id] + userState.recentStationIDs).prefix(50).map { $0 }
        try? stateStore.save(userState)
        Task { await client.registerClick(stationID: station.id) }
    }
}

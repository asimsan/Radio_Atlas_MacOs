import Combine
import Foundation
import RadioAtlasCore

enum SidebarTab: String, CaseIterable {
    case world = "World"
    case favorites = "Favorites"
    case recent = "Recent"
}

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var stations: [Station] = []
    @Published var searchQuery: String = "" {
        didSet { filteredStations = StationFilter.filter(stations, query: searchQuery) }
    }
    @Published var filteredStations: [Station] = []
    @Published var selectedTab: SidebarTab = .world
    @Published var outputDevices: [OutputDevice] = []
    @Published var selectedOutputDeviceID: String?

    let playbackController: PlaybackController
    private(set) var countryLookup: CountryLookup?
    private(set) var countryRegions: [CountryRegion] = []

    private let client = RadioBrowserClient()
    private let cache: StationCache
    private let stateStore: UserStateStore
    private var userState: UserState
    private var cancellables: Set<AnyCancellable> = []
    private let randomTuner = RandomTuner()
    private let outputDeviceProvider: OutputDeviceProviding = CoreAudioOutputDeviceProvider()

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
        objectWillChange.send()
        userState.recentStationIDs = ([station.id] + userState.recentStationIDs).prefix(50).map { $0 }
        try? stateStore.save(userState)
        Task { await client.registerClick(stationID: station.id) }
    }

    var displayedStations: [Station] {
        switch selectedTab {
        case .world:
            return filteredStations
        case .favorites:
            return stations.filter { userState.favoriteStationIDs.contains($0.id) }
        case .recent:
            return userState.recentStationIDs.compactMap { id in stations.first { $0.id == id } }
        }
    }

    func selectTab(_ tab: SidebarTab) {
        selectedTab = tab
    }

    func isFavorite(_ station: Station) -> Bool {
        userState.favoriteStationIDs.contains(station.id)
    }

    func toggleFavorite(_ station: Station) {
        objectWillChange.send()
        if userState.favoriteStationIDs.contains(station.id) {
            userState.favoriteStationIDs.remove(station.id)
        } else {
            userState.favoriteStationIDs.insert(station.id)
        }
        try? stateStore.save(userState)
    }

    func refreshOutputDevices() {
        outputDevices = [OutputDevice(id: "", name: "System default")] + outputDeviceProvider.listOutputDevices()
        selectedOutputDeviceID = userState.outputDeviceUID ?? ""
    }

    func selectOutputDevice(_ device: OutputDevice) {
        let uid: String? = device.id.isEmpty ? nil : device.id
        selectedOutputDeviceID = device.id
        playbackController.setOutputDevice(uid: uid)
        objectWillChange.send()
        userState.outputDeviceUID = uid
        try? stateStore.save(userState)
    }

    func playRandom() {
        guard let station = randomTuner.pickStation(from: filteredStations, avoiding: Set(userState.recentStationIDs)) else { return }
        play(station)
    }
}

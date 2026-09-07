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
        didSet {
            // The search pipeline lives in `StationSearchCoordinator` (Core):
            // non-country queries filter the top-stations list locally and
            // instantly, a query that names a country fetches that country's
            // full station list (debounced, stale responses discarded).
            coordinator.setQuery(searchQuery)
        }
    }
    @Published var selectedTab: SidebarTab = .world
    @Published var outputDevices: [OutputDevice] = []
    @Published var selectedOutputDeviceID: String?
    @Published var keyboardSelectedIndex: Int?
    @Published var statusMessage: String?

    /// The World tab's list (and the globe's station-dot source): the
    /// locally filtered top stations, or the active country's full list.
    var filteredStations: [Station] { coordinator.list }
    var activeCountryCode: String? { coordinator.countryCode }
    var activeCountryName: String? { coordinator.countryName }

    /// Country of the currently playing station — drives the globe's
    /// distinct playing-country highlight and the auto-rotation that brings
    /// it into view.
    var playingCountryCode: String? { playbackController.currentStation?.countryCode }
    var playingStation: Station? { playbackController.currentStation }

    /// Live aurora activity feeding the globe's data-driven bands; nil while
    /// the feed is unavailable (bands fall back to the static look).
    var auroraActivity: AuroraActivity? { auroraMonitor.activity }

    let playbackController: PlaybackController
    private(set) var countryLookup: CountryLookup?
    private(set) var countryRegions: [CountryRegion] = []
    let coordinator: StationSearchCoordinator

    private let client = RadioBrowserClient()
    private let cache: StationCache
    private let stateStore: UserStateStore
    private var userState: UserState
    private var cancellables: Set<AnyCancellable> = []
    private let randomTuner = RandomTuner()
    private let outputDeviceProvider: OutputDeviceProviding = CoreAudioOutputDeviceProvider()
    private let auroraMonitor = AuroraMonitor()
    let sleepTimer = SleepTimer()
    /// Top-stations load/refresh errors, kept separate from country-fetch
    /// errors so `updateStatusMessage()` can compose them with a stable
    /// priority.
    private var loadError: String? {
        didSet { updateStatusMessage() }
    }
    // Holds the media-key/Now Playing integration alive for the app's
    // lifetime. Never read after assignment — its `init` wires
    // `MPRemoteCommandCenter` targets and subscribes to `playbackController`
    // itself, so simply keeping it retained is the whole job.
    private var nowPlaying: NowPlayingCenter?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RadioAtlas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        cache = StationCache(directory: appSupport, filename: "top-stations.json")
        stateStore = UserStateStore(directory: appSupport)
        userState = stateStore.load()
        playbackController = PlaybackController(player: AVPlayerStreamPlayer())
        playbackController.volume = userState.volume

        if let lookup = try? CountryLookup.loadBundled() {
            countryLookup = lookup
            countryRegions = lookup.allRegions()
        }

        coordinator = StationSearchCoordinator(
            directory: client,
            regionCodes: Set(countryRegions.map(\.isoCode))
        )
        // Same nested-ObservableObject forwarding as `playbackController`
        // below — views observe `viewModel`, not the coordinator.
        coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        coordinator.$countryError
            .combineLatest(coordinator.$isLoadingCountry)
            .sink { [weak self] _, _ in self?.updateStatusMessage() }
            .store(in: &cancellables)
        auroraMonitor.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // ObservableObject does NOT automatically propagate a nested object's
        // changes to views observing the parent. SidebarView and PlayerBarView
        // (Steps 10/11) observe `viewModel`, not `playbackController` directly,
        // so without forwarding this, they would never re-render when playback
        // status changes (e.g. .idle -> .playing after tapping a station).
        playbackController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Persist volume changes back to disk (e.g. dragging the player bar's
        // slider, or the +/- keyboard shortcuts) so it survives relaunch.
        // Lightly debounced so a slider drag doesn't hammer disk on every
        // frame; `userState.volume` was already set from disk one line above,
        // so this subscription's own initial replay (Combine's `@Published`
        // emits the current value to new subscribers) is a harmless no-op
        // write of the same value.
        playbackController.$volume
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] volume in
                guard let self else { return }
                self.userState.volume = volume
                try? self.stateStore.save(self.userState)
            }
            .store(in: &cancellables)

        nowPlaying = NowPlayingCenter(controller: playbackController)
        auroraMonitor.start()

        // Populate the output-device list/selection, then restore whatever
        // was persisted (refreshOutputDevices() already falls back to system
        // default and clears the persisted UID if the saved device is no
        // longer connected, so this is safe to call unconditionally).
        refreshOutputDevices()
        if let savedUID = userState.outputDeviceUID {
            playbackController.setOutputDevice(uid: savedUID)
        }
    }

    /// Favourites and recents resolve by id against `stations`, so anything
    /// on those lists must survive deduplication or it would silently vanish
    /// from the Favourites tab.
    private var protectedStationIDs: Set<String> {
        Set(userState.favoriteStationIDs).union(userState.recentStationIDs)
    }

    func loadStations() async {
        if let cached = cache.read() {
            let unique = StationDeduplicator.deduplicate(cached, protectedIDs: protectedStationIDs)
            stations = unique
            coordinator.setBaseStations(unique)
        }
        do {
            let fresh = try await client.topStations()
            let unique = StationDeduplicator.deduplicate(fresh, protectedIDs: protectedStationIDs)
            stations = unique
            coordinator.setBaseStations(unique)
            // The raw fetch is cached, not the deduplicated list: which
            // stations are protected depends on favourites at read time, and
            // a future change to the rule shouldn't need the cache cleared.
            try? cache.write(fresh)
            loadError = nil
        } catch {
            loadError = stations.isEmpty
                ? "Couldn't load stations: \(error.localizedDescription)"
                : "Couldn't refresh stations: \(error.localizedDescription)"
        }
    }

    /// Fetches and displays the stations for a country the user clicked on
    /// the globe (the search bar reaches the same state via the coordinator's
    /// country-name matching). Switches to the World tab so the browsed list
    /// is immediately visible.
    func browseCountry(_ code: String) {
        let name = stations.first(where: { $0.countryCode == code })?.country ?? code
        coordinator.browseCountry(code: code, name: name)
        selectedTab = .world
    }

    func play(_ station: Station) {
        // The sidebar displays `displayedStations` (which differs from
        // `filteredStations` on the Favorites/Recent tabs), so look there
        // first — that's what Next/Previous should walk for a sidebar tap.
        // The globe hands back stations sourced from `filteredStations`
        // directly, so fall back to that list for globe taps.
        //
        // Matched by `id`, not full struct equality (`firstIndex(of:)`):
        // manual verification surfaced a real false-negative — a station
        // re-fetched from the network (e.g. after a country-browse refresh)
        // can have the same `id` but a different `clickCount`/`votes`, which
        // would make a struct-equality lookup silently fail to find it (and
        // silently do nothing) even though it's plainly "the same station"
        // to the user tapping it.
        let list: [Station]
        let index: Int
        if let displayedIndex = displayedStations.firstIndex(where: { $0.id == station.id }) {
            list = displayedStations
            index = displayedIndex
        } else if let filteredIndex = filteredStations.firstIndex(where: { $0.id == station.id }) {
            list = filteredStations
            index = filteredIndex
        } else {
            return
        }
        playbackController.setQueue(list, startAt: index)
        objectWillChange.send()
        userState.recordPlay(station.id)
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
        userState.toggleFavorite(station.id)
        try? stateStore.save(userState)
    }

    /// Clears the listening history backing the Recent tab.
    func clearRecentHistory() {
        objectWillChange.send()
        userState.clearRecents()
        try? stateStore.save(userState)
    }

    /// The sleep timer's expiry (nil when inactive) — drives the player
    /// bar's countdown display.
    var sleepFireDate: Date? { sleepTimer.fireDate }

    /// Schedules a sleep timer for `minutes`, or cancels it with nil. When
    /// it fires, playback pauses.
    func scheduleSleep(minutes: Int?) {
        if let minutes {
            sleepTimer.schedule(seconds: Double(minutes) * 60) { [weak self] in
                self?.playbackController.pause()
            }
        } else {
            sleepTimer.cancel()
        }
        objectWillChange.send()
    }

    func refreshOutputDevices() {
        outputDevices = [OutputDevice(id: "", name: "System default")] + outputDeviceProvider.listOutputDevices()
        let savedID = userState.outputDeviceUID ?? ""
        if outputDevices.contains(where: { $0.id == savedID }) {
            selectedOutputDeviceID = savedID
        } else {
            // The previously-selected device is no longer connected — fall
            // back to system default and clear the stale persisted UID so we
            // don't keep trying to route to a device that's gone.
            selectedOutputDeviceID = ""
            userState.outputDeviceUID = nil
            try? stateStore.save(userState)
            playbackController.setOutputDevice(uid: nil)
        }
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

    func moveKeyboardSelection(by delta: Int) {
        let list = displayedStations
        guard !list.isEmpty else { keyboardSelectedIndex = nil; return }
        let current = keyboardSelectedIndex ?? -1
        keyboardSelectedIndex = ((current + delta) % list.count + list.count) % list.count
    }

    func playKeyboardSelectedStation() {
        guard let index = keyboardSelectedIndex, displayedStations.indices.contains(index) else { return }
        play(displayedStations[index])
    }

    func retryFailedStation() {
        playbackController.togglePlayPause()
    }

    /// Exits country mode entirely (the sidebar header's ✕ button): clears
    /// the search field and returns the World tab to the top-stations list.
    func exitCountryMode() {
        searchQuery = ""
        coordinator.exitCountryMode()
    }

    /// Composes the globe pane's hint with a stable priority: station-load
    /// errors, then country-fetch errors, then the country loading hint.
    private func updateStatusMessage() {
        if let loadError {
            statusMessage = loadError
        } else if let countryError = coordinator.countryError {
            statusMessage = countryError
        } else if coordinator.isLoadingCountry, let name = coordinator.countryName {
            statusMessage = "Loading \(name)…"
        } else {
            statusMessage = nil
        }
    }

    /// Writes state that is otherwise saved on a debounce, so quitting right
    /// after a change doesn't lose it. Volume is the one that matters: its
    /// save is debounced 300ms, which a quit button makes easy to outrun.
    func prepareForTermination() {
        userState.volume = playbackController.volume
        try? stateStore.save(userState)
    }
}

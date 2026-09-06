import Foundation

public final class PlaybackController: ObservableObject {
    @Published public private(set) var status: PlaybackStatus = .idle
    @Published public private(set) var queue: [Station] = []
    @Published public private(set) var currentIndex: Int?
    @Published public var volume: Float = 1.0 {
        didSet {
            player.setVolume(volume)
            // Any nonzero volume assignment (e.g. dragging the player bar's
            // slider directly) implies the user wants sound audible, so clear
            // a stale `isMuted`. `toggleMute()`'s own muting branch sets
            // `volume = 0`, which is not nonzero, so this doesn't interfere
            // with that path. Its unmuting branch sets `isMuted = false`
            // before restoring `volume`, so this is a harmless re-assignment
            // to the same value there.
            if volume != 0 {
                isMuted = false
            }
        }
    }
    @Published public private(set) var isMuted: Bool = false
    private var volumeBeforeMute: Float = 1.0

    private let player: StreamPlaying

    public init(player: StreamPlaying) {
        self.player = player
        self.player.onStatusChange = { [weak self] status in
            self?.status = status
        }
    }

    public func setQueue(_ stations: [Station], startAt index: Int) {
        queue = stations
        currentIndex = index
        playCurrent()
    }

    public func next() {
        guard let index = currentIndex, !queue.isEmpty else { return }
        currentIndex = (index + 1) % queue.count
        playCurrent()
    }

    public func previous() {
        guard let index = currentIndex, !queue.isEmpty else { return }
        currentIndex = (index - 1 + queue.count) % queue.count
        playCurrent()
    }

    public func togglePlayPause() {
        switch status {
        case .playing:
            player.pause()
        case .paused(let station), .failed(let station, _):
            player.play(station: station)
        default:
            break
        }
    }

    public var currentStation: Station? {
        switch status {
        case .idle: return nil
        case .loading(let station), .playing(let station), .paused(let station), .failed(let station, _):
            return station
        }
    }

    public func setOutputDevice(uid: String?) {
        player.setOutputDeviceUID(uid)
    }

    public func toggleMute() {
        if isMuted {
            isMuted = false
            volume = volumeBeforeMute
        } else {
            volumeBeforeMute = volume
            isMuted = true
            volume = 0
        }
    }

    private func playCurrent() {
        guard let index = currentIndex, queue.indices.contains(index) else { return }
        player.play(station: queue[index])
    }
}

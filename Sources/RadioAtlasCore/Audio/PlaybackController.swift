import Foundation

public final class PlaybackController: ObservableObject {
    @Published public private(set) var status: PlaybackStatus = .idle
    @Published public private(set) var queue: [Station] = []
    @Published public private(set) var currentIndex: Int?
    @Published public var volume: Float = 1.0 {
        didSet { player.setVolume(volume) }
    }

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
            player.play(url: station.streamURL)
        default:
            break
        }
    }

    public func setOutputDevice(uid: String?) {
        player.setOutputDeviceUID(uid)
    }

    private func playCurrent() {
        guard let index = currentIndex, queue.indices.contains(index) else { return }
        player.play(url: queue[index].streamURL)
    }
}

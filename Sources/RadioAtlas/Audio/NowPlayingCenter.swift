import Combine
import MediaPlayer
import RadioAtlasCore

@MainActor
final class NowPlayingCenter {
    private var cancellable: AnyCancellable?

    init(controller: PlaybackController) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in controller.togglePlayPause(); return .success }
        commandCenter.pauseCommand.addTarget { _ in controller.togglePlayPause(); return .success }
        commandCenter.nextTrackCommand.addTarget { _ in controller.next(); return .success }
        commandCenter.previousTrackCommand.addTarget { _ in controller.previous(); return .success }

        cancellable = controller.$status.sink { status in
            let info = MPNowPlayingInfoCenter.default()
            switch status {
            case .playing(let station), .paused(let station), .loading(let station), .failed(let station, _):
                info.nowPlayingInfo = [MPMediaItemPropertyTitle: station.name]
            case .idle:
                info.nowPlayingInfo = nil
            }
        }
    }
}

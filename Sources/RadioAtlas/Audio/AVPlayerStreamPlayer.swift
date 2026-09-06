import AVFoundation
import RadioAtlasCore

/// Real `StreamPlaying` implementation backed by `AVPlayer`. Output-device
/// routing (including AirPlay) goes through `AVPlayer.audioOutputDeviceUniqueID`,
/// which is the per-player API that makes this work on macOS.
///
/// Deviation from the brief's reference code (two bugs, both fixed here):
///
/// 1. The reference `play(url:)` never assigned `currentStation`, so the KVO
///    closure's `guard let station = self.currentStation else { return }`
///    was always false (the property stays `nil` forever) — `onStatusChange`
///    would never fire for real playback, so `PlaybackController.status`
///    would stay `.idle` forever and the whole play/pause/media-key feature
///    this task exists to add would silently never work. Fixed by assigning
///    `currentStation` at the top of `play(station:)`.
///
///    Originally I fixed this by widening `StreamPlaying.play(url:)` to keep
///    taking just a `URL` and building a placeholder `Station` from it inside
///    this file (plus a supporting public init added to `Station`). That
///    placeholder had a real, user-visible cost: Task 11's `NowPlayingCard`
///    reads `station.name` straight out of `PlaybackStatus` to show in the
///    panel UI, so a URL-derived placeholder would display the wrong title
///    the moment Task 11 wired it up. Fixed properly instead by widening
///    `StreamPlaying.play(url:)` to `play(station: Station)`, so
///    `AVPlayerStreamPlayer` always receives the real `Station` (with full
///    metadata) that `PlaybackController` already tracks in `queue`. The
///    `Station.swift` public-init workaround was reverted — no longer needed
///    since nothing here constructs a `Station` from scratch anymore.
/// 2. The reference `pause()` called `player.pause()` but never reported a
///    `.paused` status transition. Since `PlaybackController.togglePlayPause()`
///    only resumes when `status` is `.paused`/`.failed`, without this the
///    status would stay stuck at `.playing` after the first pause, so a
///    second play/pause key press would just call `pause()` again instead of
///    resuming — pause could never be undone via the controller. Fixed by
///    echoing `.paused(station)` through `onStatusChange` after pausing.
final class AVPlayerStreamPlayer: StreamPlaying {
    var onStatusChange: ((PlaybackStatus) -> Void)?

    private let player = AVPlayer()
    private var currentStation: Station?
    private var statusObservation: NSKeyValueObservation?

    func play(station: Station) {
        currentStation = station

        let item = AVPlayerItem(url: station.streamURL)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self, let station = self.currentStation else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.onStatusChange?(.playing(station))
                case .failed:
                    self.onStatusChange?(.failed(station, message: item.error?.localizedDescription ?? "Playback failed"))
                default:
                    break
                }
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func pause() {
        player.pause()
        guard let station = currentStation else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChange?(.paused(station))
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func setVolume(_ volume: Float) {
        player.volume = volume
    }

    func setOutputDeviceUID(_ uid: String?) {
        player.audioOutputDeviceUniqueID = uid
    }
}

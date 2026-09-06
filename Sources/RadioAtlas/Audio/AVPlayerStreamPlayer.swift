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
///    `currentStation` at the top of `play(url:)`.
/// 2. The reference `pause()` called `player.pause()` but never reported a
///    `.paused` status transition. Since `PlaybackController.togglePlayPause()`
///    only resumes when `status` is `.paused`/`.failed`, without this the
///    status would stay stuck at `.playing` after the first pause, so a
///    second play/pause key press would just call `pause()` again instead of
///    resuming — pause could never be undone via the controller. Fixed by
///    echoing `.paused(station)` through `onStatusChange` after pausing.
///
/// Both fixes reuse `currentStation`, but `StreamPlaying.play(url:)` only
/// receives a `URL` (that signature is fixed by Task 9 Step 3's protocol,
/// already implemented and unit-tested against `FakeStreamPlayer.playedURLs:
/// [URL]`), so this class has no way to recover the original `Station`'s rich
/// metadata (name, tags, country, ...) — only the URL it was asked to play.
/// `placeholderStation(for:)` builds a minimal `Station` keyed off that URL
/// so the `PlaybackStatus` state machine works end-to-end: `togglePlayPause()`
/// only reads `station.streamURL` from the `.paused`/`.failed` cases to
/// resume/retry, which is correct here. The tradeoff is cosmetic:
/// `NowPlayingCenter`'s displayed title falls back to the URL rather than the
/// station's real name. `PlaybackController` itself already tracks the real
/// `Station` in `queue`/`currentIndex`, so a future task's panel UI can read
/// the friendly name from there instead of from `PlaybackStatus` if needed.
final class AVPlayerStreamPlayer: StreamPlaying {
    var onStatusChange: ((PlaybackStatus) -> Void)?

    private let player = AVPlayer()
    private var currentStation: Station?
    private var statusObservation: NSKeyValueObservation?

    func play(url: URL) {
        let station = Self.placeholderStation(for: url)
        currentStation = station

        let item = AVPlayerItem(url: url)
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

    private static func placeholderStation(for url: URL) -> Station {
        Station(
            id: url.absoluteString,
            name: url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent,
            streamURL: url,
            homepage: nil,
            faviconURL: nil,
            tags: [],
            countryCode: "",
            country: "",
            latitude: nil,
            longitude: nil,
            votes: 0,
            clickCount: 0,
            bitrateKbps: 0
        )
    }
}

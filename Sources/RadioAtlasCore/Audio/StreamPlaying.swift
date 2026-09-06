import Foundation

public enum PlaybackStatus: Equatable {
    case idle
    case loading(Station)
    case playing(Station)
    case paused(Station)
    case failed(Station, message: String)
}

/// Abstraction over the real audio player so PlaybackController's queue/state
/// logic can be unit tested without touching AVFoundation or the network.
public protocol StreamPlaying: AnyObject {
    var onStatusChange: ((PlaybackStatus) -> Void)? { get set }
    func play(url: URL)
    func pause()
    func stop()
    func setVolume(_ volume: Float)
    func setOutputDeviceUID(_ uid: String?)
}

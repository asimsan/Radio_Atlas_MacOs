import RadioAtlasCore
import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var playbackController: PlaybackController
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let outputDevices: [OutputDevice]
    let selectedOutputDeviceID: String?
    let onSelectOutputDevice: (OutputDevice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Palette.divider).frame(height: 1)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nowPlayingTitle)
                        .font(Palette.monoBody)
                        .fontWeight(isPlaying ? .bold : .regular)
                        .foregroundStyle(Palette.foreground)
                        .lineLimit(1)
                    Text(statusLine)
                        .font(Palette.monoCaption)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }
                Spacer()
                if currentStation != nil {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isFavorite ? Palette.favorite : Palette.foreground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                Button(action: playbackController.previous) { Image(systemName: "backward.end.fill") }
                Button(action: playbackController.togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                Button(action: playbackController.next) { Image(systemName: "forward.end.fill") }
                Spacer()
                OutputPickerView(
                    devices: outputDevices,
                    selectedID: selectedOutputDeviceID,
                    onSelect: onSelectOutputDevice
                )
                Button(action: playbackController.toggleMute) {
                    Image(systemName: playbackController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                Slider(value: Binding(
                    get: { Double(playbackController.volume) },
                    set: { playbackController.volume = Float($0) }
                ), in: 0...1)
                .frame(width: 100)
                .tint(Palette.accent)
                Text("\(Int(playbackController.volume * 100))%")
                    .font(Palette.monoCaption)
                    .foregroundStyle(Palette.dim)
                    .frame(width: 36, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.foreground)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(height: 126)
        .background(Palette.background)
    }

    private var currentStation: Station? {
        switch playbackController.status {
        case .idle: return nil
        case .loading(let s), .playing(let s), .paused(let s), .failed(let s, _): return s
        }
    }

    private var isPlaying: Bool {
        if case .playing = playbackController.status { return true }
        return false
    }

    private var nowPlayingTitle: String { currentStation?.name ?? "Nothing playing" }

    private var statusLine: String {
        switch playbackController.status {
        case .idle: return "Choose a signal to begin"
        case .loading: return "Loading…"
        case .playing: return "Live"
        case .paused: return "Paused"
        case .failed(_, let message): return "\(message). Play to retry, or Next."
        }
    }

    private var statusColor: Color {
        if case .failed = playbackController.status { return Palette.urgent }
        return Palette.dim
    }
}

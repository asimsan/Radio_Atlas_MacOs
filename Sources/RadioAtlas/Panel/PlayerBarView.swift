import RadioAtlasCore
import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var playbackController: PlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Palette.divider).frame(height: 1)
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
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                Button(action: playbackController.previous) { Image(systemName: "backward.end.fill") }
                Button(action: playbackController.togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                Button(action: playbackController.next) { Image(systemName: "forward.end.fill") }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.foreground)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(height: 126)
        .background(Palette.background)
    }

    private var isPlaying: Bool {
        if case .playing = playbackController.status { return true }
        return false
    }

    private var nowPlayingTitle: String {
        switch playbackController.status {
        case .idle: return "Nothing playing"
        case .loading(let s), .playing(let s), .paused(let s), .failed(let s, _): return s.name
        }
    }

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

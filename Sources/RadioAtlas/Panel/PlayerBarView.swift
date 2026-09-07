import RadioAtlasCore
import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var playbackController: PlaybackController
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let outputDevices: [OutputDevice]
    let selectedOutputDeviceID: String?
    let onSelectOutputDevice: (OutputDevice) -> Void
    let onRetry: () -> Void
    let sleepFireDate: Date?
    let onScheduleSleep: (Int?) -> Void
    /// The floating mini window is far narrower than the panel's sidebar, so
    /// it allows the name a second line. Station names run to 399 characters
    /// in the live directory, so this only ever widens the common case — the
    /// tooltip carries the full name for the rest.
    var nameLineLimit: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Palette.divider).frame(height: 1)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nowPlayingTitle)
                        .font(Palette.monoBody)
                        .fontWeight(isPlaying ? .bold : .regular)
                        .foregroundStyle(Palette.foreground)
                        .lineLimit(nameLineLimit)
                        // Wrap onto the allowed lines instead of truncating
                        // at the first.
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(nowPlayingTitle)
                    if case .failed = playbackController.status {
                        HStack(spacing: 8) {
                            Text(statusLine)
                                .font(Palette.monoCaption)
                                .foregroundStyle(statusColor)
                                .lineLimit(1)
                            Button("Retry", action: onRetry)
                                .buttonStyle(.plain)
                                .font(Palette.monoCaption).bold()
                                .foregroundStyle(Palette.accent)
                        }
                    } else {
                        Text(statusLine)
                            .font(Palette.monoCaption)
                            .foregroundStyle(statusColor)
                            .lineLimit(1)
                    }
                }
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

            // The mini window resizes down to 320pt, but the full row cannot
            // compress below 379pt: its slider is a fixed 100pt and the volume
            // label a fixed 36pt. Overflowing made the enclosing VStack wider
            // than the window, which then centred it and pushed the station
            // name's leading characters off the left edge -- "Sveriges Radio"
            // losing its "Sv". The compact variant fits in 243pt.
            ViewThatFits(in: .horizontal) {
                controlRow(compact: false)
                controlRow(compact: true)
            }
            .padding(.bottom, 12)
        }
        // minHeight, not a fixed height: a wrapped second line has to have
        // somewhere to go. Single-line callers are unaffected.
        .frame(minHeight: 126)
        .background(Palette.background)
    }

    /// `compact` drops the two labels that only annotate what an icon
    /// already shows -- the volume percentage and the sleep countdown -- and
    /// lets the slider shrink, so the row survives a narrow mini window.
    @ViewBuilder
    private func controlRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            Button(action: playbackController.previous) { Image(systemName: "backward.end.fill") }
            Button(action: playbackController.togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            Button(action: playbackController.next) { Image(systemName: "forward.end.fill") }
            Menu {
                Button("Off") { onScheduleSleep(nil) }
                Divider()
                Button("15 minutes") { onScheduleSleep(15) }
                Button("30 minutes") { onScheduleSleep(30) }
                Button("60 minutes") { onScheduleSleep(60) }
            } label: {
                Image(systemName: sleepFireDate != nil ? "moon.zzz.fill" : "moon.zzz")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .foregroundStyle(Palette.foreground)
            .help("Sleep timer")
            if sleepFireDate != nil, !compact {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(remainingText(at: timeline.date))
                        .font(Palette.monoCaption)
                        .foregroundStyle(Palette.dim)
                }
            }
            Spacer(minLength: 4)
            OutputPickerView(
                devices: outputDevices,
                selectedID: selectedOutputDeviceID,
                onSelect: onSelectOutputDevice
            )
            Button(action: playbackController.toggleMute) {
                Image(systemName: playbackController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            volumeSlider
                .frame(minWidth: compact ? 48 : 100, maxWidth: 100)
                .tint(Palette.accent)
            if !compact {
                Text("\(Int(playbackController.volume * 100))%")
                    .font(Palette.monoCaption)
                    .foregroundStyle(Palette.dim)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.foreground)
        .padding(.horizontal, compact ? 12 : 16)
    }

    private var volumeSlider: some View {
        Slider(value: Binding(
            get: { Double(playbackController.volume) },
            set: { playbackController.volume = Float($0) }
        ), in: 0...1)
    }

    private var currentStation: Station? { playbackController.currentStation }

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

    private func remainingText(at date: Date) -> String {
        let remaining = max(0, Int((sleepFireDate ?? date).timeIntervalSince(date)))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}

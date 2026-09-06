import RadioAtlasCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button(tab.rawValue) { viewModel.selectTab(tab) }
                        .buttonStyle(.plain)
                        .font(Palette.monoCaption)
                        .foregroundStyle(viewModel.selectedTab == tab ? Palette.accent : Palette.foreground)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            Rectangle().fill(Palette.divider).frame(height: 1)

            if viewModel.displayedStations.isEmpty {
                Spacer()
                Text(emptyStateText)
                    .font(Palette.monoBody)
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.displayedStations) { station in
                            VStack(spacing: 0) {
                                StationRow(
                                    station: station,
                                    isPlaying: isPlaying(station),
                                    isFavorite: viewModel.isFavorite(station),
                                    onTap: { viewModel.play(station) },
                                    onToggleFavorite: { viewModel.toggleFavorite(station) }
                                )
                                Rectangle().fill(Palette.divider).frame(height: 1)
                            }
                        }
                    }
                }
            }

            PlayerBarView(
                playbackController: viewModel.playbackController,
                isFavorite: currentStation.map(viewModel.isFavorite) ?? false,
                onToggleFavorite: { if let station = currentStation { viewModel.toggleFavorite(station) } },
                outputDevices: viewModel.outputDevices,
                selectedOutputDeviceID: viewModel.selectedOutputDeviceID,
                onSelectOutputDevice: viewModel.selectOutputDevice
            )
        }
        .background(Palette.background)
        .onAppear { viewModel.refreshOutputDevices() }
    }

    private var currentStation: Station? {
        switch viewModel.playbackController.status {
        case .idle: return nil
        case .loading(let s), .playing(let s), .paused(let s), .failed(let s, _): return s
        }
    }

    private func isPlaying(_ station: Station) -> Bool {
        currentStation?.id == station.id
    }

    private var emptyStateText: String {
        switch viewModel.selectedTab {
        case .world: return "No working stations found."
        case .favorites: return "No favorites yet. Select a station and press F."
        case .recent: return "No listening history yet."
        }
    }
}

private struct StationRow: View {
    let station: Station
    let isPlaying: Bool
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(Palette.monoBody)
                    .fontWeight(isPlaying ? .bold : .regular)
                    .foregroundStyle(Palette.foreground)
                    .lineLimit(1)
                Text(metaLine)
                    .font(Palette.monoCaption)
                    .foregroundStyle(Palette.dim)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            .foregroundStyle(isFavorite ? Palette.favorite : Palette.foreground)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(isPlaying ? Palette.selectedRow : Color.clear)
        .overlay(alignment: .leading) {
            if isPlaying {
                Rectangle().fill(Palette.accent).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var metaLine: String {
        var parts = [station.countryCode]
        if station.bitrateKbps > 0 { parts.append("\(station.bitrateKbps) kbps") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

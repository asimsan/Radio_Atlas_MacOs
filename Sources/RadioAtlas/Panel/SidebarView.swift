import RadioAtlasCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PanelViewModel
    @State private var confirmClearRecents = false

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

            // Country-mode header (globe click or country search): the browsed
            // country, its station count, and a one-click way back out.
            if let countryName = viewModel.activeCountryName, viewModel.selectedTab == .world {
                HStack {
                    Text("\(countryName.uppercased()) · \(viewModel.displayedStations.count) stations")
                        .font(Palette.monoCaption)
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { viewModel.exitCountryMode() }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.dim)
                    .help("Exit country browse")
                }
                .padding(.horizontal, 16)
                .frame(height: 32)
                Rectangle().fill(Palette.divider).frame(height: 1)
            }

            // Recent-tab header: history count and a confirmed way to clear it.
            if viewModel.selectedTab == .recent, !viewModel.displayedStations.isEmpty {
                HStack {
                    Text("\(viewModel.displayedStations.count) stations")
                        .font(Palette.monoCaption)
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Button {
                        confirmClearRecents = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.dim)
                    .help("Clear listening history")
                    .confirmationDialog("Clear listening history?", isPresented: $confirmClearRecents) {
                        Button("Clear History", role: .destructive) { viewModel.clearRecentHistory() }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 32)
                Rectangle().fill(Palette.divider).frame(height: 1)
            }

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
                        ForEach(Array(viewModel.displayedStations.enumerated()), id: \.element.id) { index, station in
                            VStack(spacing: 0) {
                                StationRow(
                                    station: station,
                                    isPlaying: isPlaying(station),
                                    isFavorite: viewModel.isFavorite(station),
                                    isKeyboardSelected: viewModel.keyboardSelectedIndex == index,
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
                onSelectOutputDevice: viewModel.selectOutputDevice,
                onRetry: { viewModel.retryFailedStation() },
                sleepFireDate: viewModel.sleepFireDate,
                onScheduleSleep: { viewModel.scheduleSleep(minutes: $0) }
            )
        }
        .background(Palette.background)
        .onAppear { viewModel.refreshOutputDevices() }
    }

    private var currentStation: Station? { viewModel.playbackController.currentStation }

    private func isPlaying(_ station: Station) -> Bool {
        currentStation?.id == station.id
    }

    private var emptyStateText: String {
        switch viewModel.selectedTab {
        case .world:
            if !viewModel.searchQuery.isEmpty {
                return "No stations match \"\(viewModel.searchQuery)\"."
            }
            return "No working stations found."
        case .favorites: return "No favorites yet. Select a station and press F."
        case .recent: return "No listening history yet."
        }
    }
}

private struct StationRow: View {
    let station: Station
    let isPlaying: Bool
    let isFavorite: Bool
    let isKeyboardSelected: Bool
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
        .overlay {
            if isKeyboardSelected && !isPlaying {
                Rectangle().strokeBorder(Palette.accent, lineWidth: 1)
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

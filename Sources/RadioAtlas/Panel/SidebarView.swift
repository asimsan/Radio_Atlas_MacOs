import RadioAtlasCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PanelViewModel
    @State private var selectedTab: String = "World"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                tabButton("World")
                tabButton("Favorites")
                tabButton("Recent")
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            Rectangle().fill(Palette.divider).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredStations) { station in
                        VStack(spacing: 0) {
                            StationRow(station: station, isPlaying: isPlaying(station)) {
                                viewModel.play(station)
                            }
                            Rectangle().fill(Palette.divider).frame(height: 1)
                        }
                    }
                }
            }

            PlayerBarView(playbackController: viewModel.playbackController)
        }
        .background(Palette.background)
    }

    private func isPlaying(_ station: Station) -> Bool {
        if case .playing(let playing) = viewModel.playbackController.status { return playing.id == station.id }
        return false
    }

    private func tabButton(_ title: String) -> some View {
        Button(title) { selectedTab = title }
            .buttonStyle(.plain)
            .font(Palette.monoCaption)
            .foregroundStyle(selectedTab == title ? Palette.accent : Palette.foreground)
    }
}

private struct StationRow: View {
    let station: Station
    let isPlaying: Bool
    let onTap: () -> Void

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

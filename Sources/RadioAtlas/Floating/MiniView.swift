import RadioAtlasCore
import SwiftUI

/// The floating mini window: a compact card with a drag-friendly header, the
/// same live globe (Canvas scales to any size), and the full player bar.
/// Shares `PanelViewModel` with the menu bar panel, so playback, search,
/// favorites, and the aurora state are one and the same.
struct MiniView: View {
    @ObservedObject var viewModel: PanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Drag header. This row sits exactly on the window's 32pt
            // transparent title bar, which is what moves the window — the
            // rest of the window is deliberately not draggable so that
            // dragging the globe rotates it.
            HStack(spacing: 8) {
                Text("RADIO ATLAS")
                    .font(Palette.monoCaption).bold()
                    .foregroundStyle(Palette.foreground)
                Spacer()
                Button {
                    FloatingWindowManager.shared.hide()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.dim)
                .help("Hide floating window")
            }
            // .hiddenTitleBar keeps the traffic lights visible and
            // fullSizeContentView floats them over the content at x 9...69,
            // y 9...23 -- directly on top of this 32pt header. Inset the
            // leading edge so the title clears them.
            .padding(.leading, 76)
            .padding(.trailing, 12)
            .frame(height: 32)
            Rectangle().fill(Palette.divider).frame(height: 1)

            GlobePaneView(
                stations: viewModel.filteredStations,
                countryLookup: viewModel.countryLookup,
                regions: viewModel.countryRegions,
                activeCountryCode: viewModel.activeCountryCode,
                activeCountryName: viewModel.activeCountryName,
                playingCountryCode: viewModel.playingCountryCode,
                playingStation: viewModel.playingStation,
                auroraActivity: viewModel.auroraActivity,
                statusMessage: viewModel.statusMessage,
                onStationTapped: { viewModel.play($0) },
                onCountryTapped: { viewModel.browseCountry($0) }
            )

            PlayerBarView(
                playbackController: viewModel.playbackController,
                isFavorite: viewModel.playingStation.map(viewModel.isFavorite) ?? false,
                onToggleFavorite: {
                    if let station = viewModel.playingStation { viewModel.toggleFavorite(station) }
                },
                outputDevices: viewModel.outputDevices,
                selectedOutputDeviceID: viewModel.selectedOutputDeviceID,
                onSelectOutputDevice: viewModel.selectOutputDevice,
                onRetry: { viewModel.retryFailedStation() },
                sleepFireDate: viewModel.sleepFireDate,
                onScheduleSleep: { viewModel.scheduleSleep(minutes: $0) },
                nameLineLimit: 2
            )
        }
        .frame(minWidth: 320, idealWidth: 400, maxWidth: .infinity,
               minHeight: 380, idealHeight: 520, maxHeight: .infinity)
        .background(Palette.background)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.refreshOutputDevices() }
    }
}

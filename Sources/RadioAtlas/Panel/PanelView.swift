import RadioAtlasCore
import SwiftUI

struct PanelView: View {
    @StateObject private var viewModel = PanelViewModel()
    @State private var helpVisible = false
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                searchQuery: $viewModel.searchQuery,
                searchFieldFocus: $searchFieldFocused,
                helpVisible: helpVisible,
                onRandom: { viewModel.playRandom() },
                onToggleHelp: { helpVisible.toggle() },
                onClose: { NSApp.keyWindow?.close() }
            )
            if helpVisible {
                HelpOverlayView()
            } else {
                HStack(spacing: 0) {
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
                    Rectangle().fill(Palette.divider).frame(width: 1)
                    SidebarView(viewModel: viewModel)
                        .frame(width: 390)
                }
            }
        }
        .frame(minWidth: 800, idealWidth: 1180, minHeight: 560, idealHeight: 760)
        .background(Palette.background)
        // `Palette` hardcodes dark colors, but nothing else forces dark
        // rendering — under a Light system appearance, system-drawn chrome
        // (TextField, Slider, popover materials) would use light-mode system
        // colors against these dark custom backgrounds (e.g. near-black
        // search text on a near-black background). Forcing it here applies
        // to the whole subtree, including the help overlay and any popovers.
        .preferredColorScheme(.dark)
        .radioAtlasKeyboardShortcuts(
            viewModel: viewModel,
            helpVisible: $helpVisible,
            searchFieldFocus: $searchFieldFocused,
            onClose: { NSApp.keyWindow?.close() }
        )
        .task { await viewModel.loadStations() }
    }
}

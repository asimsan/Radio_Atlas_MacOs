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
                        activeCountryCode: nil,
                        activeCountryName: nil,
                        onStationTapped: { viewModel.play($0) },
                        onCountryTapped: { _ in }
                    )
                    Rectangle().fill(Palette.divider).frame(width: 1)
                    SidebarView(viewModel: viewModel)
                        .frame(width: 390)
                }
            }
        }
        .frame(minWidth: 800, idealWidth: 1180, minHeight: 560, idealHeight: 760)
        .background(Palette.background)
        .radioAtlasKeyboardShortcuts(
            viewModel: viewModel,
            helpVisible: $helpVisible,
            searchFieldFocus: $searchFieldFocused,
            onClose: { NSApp.keyWindow?.close() }
        )
        .task { await viewModel.loadStations() }
    }
}

import SwiftUI

extension View {
    func radioAtlasKeyboardShortcuts(
        viewModel: PanelViewModel,
        helpVisible: Binding<Bool>,
        searchFieldFocus: FocusState<Bool>.Binding,
        onClose: @escaping () -> Void
    ) -> some View {
        self
            .background(Button("") { viewModel.playbackController.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: []).hidden())
            .background(Button("") { viewModel.playRandom() }
                .keyboardShortcut("r", modifiers: []).hidden())
            .background(Button("") {
                if let station = viewModel.playbackController.currentStation {
                    viewModel.toggleFavorite(station)
                }
            }.keyboardShortcut("f", modifiers: []).hidden())
            .background(Button("") { viewModel.playbackController.toggleMute() }
                .keyboardShortcut("m", modifiers: []).hidden())
            .background(Button("") {
                viewModel.playbackController.volume = min(1, viewModel.playbackController.volume + 0.05)
            }.keyboardShortcut("+", modifiers: []).hidden())
            .background(Button("") {
                viewModel.playbackController.volume = max(0, viewModel.playbackController.volume - 0.05)
            }.keyboardShortcut("-", modifiers: []).hidden())
            .background(Button("") { viewModel.moveKeyboardSelection(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: []).hidden())
            .background(Button("") { viewModel.moveKeyboardSelection(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: []).hidden())
            .background(Button("") { viewModel.playKeyboardSelectedStation() }
                .keyboardShortcut(.return, modifiers: []).hidden())
            .background(Button("") { searchFieldFocus.wrappedValue = true }
                .keyboardShortcut("/", modifiers: []).hidden())
            .background(Button("") { helpVisible.wrappedValue.toggle() }
                .keyboardShortcut("?", modifiers: []).hidden())
            .background(Button("") {
                if !viewModel.searchQuery.isEmpty {
                    viewModel.searchQuery = ""
                } else if helpVisible.wrappedValue {
                    helpVisible.wrappedValue = false
                } else {
                    onClose()
                }
            }.keyboardShortcut(.escape, modifiers: []).hidden())
    }
}

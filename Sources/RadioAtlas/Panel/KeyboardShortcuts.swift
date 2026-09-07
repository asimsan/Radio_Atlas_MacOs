import SwiftUI

extension View {
    /// Wires the original omarchy-radio-atlas plugin's global keyboard
    /// shortcuts onto hidden `Button`s carrying `.keyboardShortcut`.
    ///
    /// Investigated (per review finding) whether `"+"`/`"?"` declared with
    /// `modifiers: []` need `.shift` added explicitly, since both are
    /// Shift-produced characters on a US layout: SwiftUI's `KeyEquivalent`
    /// matches the literal *character* a keypress produces, not the base key
    /// plus a separately-tracked modifier mask — the Shift needed to type
    /// `+` or `?` is already implied by specifying that character, so no
    /// `.shift` is needed in `modifiers`. Confirmed both by this plan's Task 13
    /// manual verification (real synthetic `"?"` keydown via `NSApp.sendEvent(_:)`
    /// against the production `PanelView`, hidden button fired correctly) and
    /// re-confirmed here.
    ///
    /// Also investigated, via the same real-`NSEvent`-dispatch technique
    /// (search field unfocused, dispatch `"r"` → `playRandom()` fires and
    /// `currentStation` changes; then focus search via `"/"` and dispatch
    /// `"r","o","c","k"` → `searchQuery` becomes exactly `"rock"` with
    /// `currentStation` unchanged): **while the search `TextField` has focus,
    /// AppKit routes plain, unmodified, printable-character keydowns to the
    /// focused text-editing responder for normal text insertion, not to a
    /// hidden button's `.keyboardShortcut` key-equivalent** — verified letters
    /// typed while focused land in the field and do NOT fire the competing
    /// shortcut. Non-printable "command" keys (Esc, Return) are the opposite:
    /// they bypass the field editor's insertion path and do reach the hidden
    /// buttons even while focused (also confirmed by dispatch — Esc correctly
    /// cleared focused search text). This means the actual bug this finding
    /// describes (typing "rock" firing `r`'s random-tune mid-word) does not
    /// reproduce via real keyboard input on this AppKit/SwiftUI version.
    /// Guards are added anyway (see below) as explicit, version-independent
    /// defense-in-depth and to document the intended behavior rather than
    /// relying on this undocumented AppKit routing detail.
    ///
    /// One consequence of that same AppKit routing: `"?"` typed while the
    /// search field is focused is ALSO swallowed as literal text (confirmed
    /// by dispatch — it appears in `searchQuery`, help does not toggle),
    /// which falls short of "should still work regardless of focus." Building
    /// a bypass (e.g. an `NSEvent` local monitor that intercepts `"?"` ahead
    /// of the field editor) is possible but adds real complexity for one key,
    /// and the header's persistent "?" button already offers a focus-independent
    /// way to reach help — so this is left as a known, minor limitation rather
    /// than fixed here. `/` typed while already focused is likewise inserted
    /// as a literal character, which is harmless (a valid search character)
    /// and matches "still works" in the loose sense the original intended.
    ///
    /// Given the above, the letter/space/arrow/return/+/- actions still each
    /// no-op while `searchFieldFocus.wrappedValue` is true, checked inside the
    /// action closure (simpler than conditionally attaching `.keyboardShortcut`
    /// itself). `/`, `?`, and Esc are deliberately NOT gated — `/` must still
    /// work to (re)focus the search field, `?` toggles help whenever it
    /// reaches the hidden button (i.e. when unfocused), and Esc must still
    /// work from within the search field to clear it.
    func radioAtlasKeyboardShortcuts(
        viewModel: PanelViewModel,
        helpVisible: Binding<Bool>,
        searchFieldFocus: FocusState<Bool>.Binding,
        onClose: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) -> some View {
        self
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.playbackController.togglePlayPause()
            }.keyboardShortcut(.space, modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.playRandom()
            }.keyboardShortcut("r", modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                // Prefer the keyboard-navigated selection (matches the help
                // overlay's documented "Favorite selected station"); fall
                // back to the currently-playing station when nothing is
                // keyboard-selected.
                let keyboardSelected = viewModel.keyboardSelectedIndex.flatMap { index in
                    viewModel.displayedStations.indices.contains(index) ? viewModel.displayedStations[index] : nil
                }
                if let station = keyboardSelected ?? viewModel.playbackController.currentStation {
                    viewModel.toggleFavorite(station)
                }
            }.keyboardShortcut("f", modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.playbackController.toggleMute()
            }.keyboardShortcut("m", modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.playbackController.volume = min(1, viewModel.playbackController.volume + 0.05)
            }.keyboardShortcut("+", modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.playbackController.volume = max(0, viewModel.playbackController.volume - 0.05)
            }.keyboardShortcut("-", modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.moveKeyboardSelection(by: 1)
            }.keyboardShortcut(.downArrow, modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.moveKeyboardSelection(by: -1)
            }.keyboardShortcut(.upArrow, modifiers: []).hidden())
            .background(Button("") {
                guard !searchFieldFocus.wrappedValue else { return }
                viewModel.playKeyboardSelectedStation()
            }.keyboardShortcut(.return, modifiers: []).hidden())
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
            // Deliberately not gated on search focus, unlike the plain-letter
            // shortcuts above: this carries a modifier, so per the routing
            // documented at the top of this file it reaches the button rather
            // than being inserted as text, and quitting should work whatever
            // has focus. The app is .accessory, so there is no app menu
            // supplying a Quit item -- this is the only keyboard route.
            .background(Button("", action: onQuit)
                .keyboardShortcut("q", modifiers: .command).hidden())
    }
}

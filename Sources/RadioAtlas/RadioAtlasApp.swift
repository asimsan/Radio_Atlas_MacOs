import SwiftUI

@main
struct RadioAtlasApp: App {
    /// One view model for both windows — the floating mini window and the
    /// menu bar panel share playback, favorites, search, and aurora state.
    @StateObject private var viewModel = PanelViewModel()

    init() {
        // Keep the app accessory-only (no Dock icon) even though a Window
        // scene exists. `NSApp` isn't available yet during App.init, so this
        // runs right after launch — after SwiftUI's own scene-based policy
        // decision, which this overrides.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        MenuBarExtra("Radio Atlas", systemImage: "globe") {
            PanelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Radio Atlas Mini", id: "mini") {
            MiniView(viewModel: viewModel)
                .background(FloatingWindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        // Without this the window opens at SwiftUI's default 900x450 -- the
        // frame's idealWidth/idealHeight are not consulted under
        // .contentMinSize, so the "widget" would launch larger than the panel.
        .defaultSize(width: 400, height: 520)
        .defaultPosition(.topTrailing)
    }
}

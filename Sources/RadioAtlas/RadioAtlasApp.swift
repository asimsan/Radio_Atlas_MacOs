import SwiftUI

@main
struct RadioAtlasApp: App {
    var body: some Scene {
        MenuBarExtra("Radio Atlas", systemImage: "globe") {
            PanelView()
        }
        .menuBarExtraStyle(.window)
    }
}

import AppKit
import SwiftUI

/// Forces its host window to the dark system appearance.
///
/// `.preferredColorScheme(.dark)` is the SwiftUI way to do this and is applied
/// on `PanelView`, but it does not reach a `MenuBarExtra` panel: measured under
/// a Light system appearance, the panel window's `effectiveAppearance` stays
/// `NSAppearanceNameAqua`. Every system-drawn control in the panel then renders
/// with light-mode colors against `Palette`'s hardcoded dark backgrounds — most
/// visibly the search field's near-black text on the near-black
/// `Palette.elevated`, but the volume slider and the output-picker popover are
/// affected the same way.
///
/// Setting `NSWindow.appearance` directly does reach it (verified: the same
/// panel window then reports `darkAqua`), and fixes every system control at
/// once rather than one at a time.
struct DarkAppearanceEnforcer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { AppearanceView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class AppearanceView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

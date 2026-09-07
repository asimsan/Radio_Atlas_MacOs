import AppKit
import Combine
import SwiftUI

/// Holds the floating mini window's `NSWindow` so the menu bar panel's
/// toggle can show/hide it with `orderOut`/`orderFront` instead of SwiftUI's
/// `openWindow`/`dismissWindow` pair — dismissing a Window scene on macOS 13
/// releases it, and reopening is unreliable there.
@MainActor
final class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()

    @Published private(set) var window: NSWindow?
    private var didApplyStyle = false

    /// Called once by the mini window's background accessor when the window
    /// is attached; applies the floating-widget window style.
    func register(_ window: NSWindow) {
        self.window = window
        guard !didApplyStyle else { return }
        didApplyStyle = true
        window.level = .floating
        window.hidesOnDeactivate = false
        // Deliberately NOT movable by background. AppKit decides a
        // background drag from the hit view's `mouseDownCanMoveWindow`, and
        // over SwiftUI content that is true — so with this enabled, dragging
        // the globe moved the window instead of spinning the globe, and the
        // mini window's globe could not be rotated at all. The window stays
        // draggable by its transparent title bar, measured at exactly 32pt,
        // which is precisely MiniView's header row.
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Same reason as DarkAppearanceEnforcer: Palette is hardcoded dark, so
        // system-drawn chrome must not fall back to light-mode colors.
        window.appearance = NSAppearance(named: .darkAqua)
    }

    /// Shows or hides the mini window. The first call creates the window
    /// through the provided `open` action; later calls toggle visibility.
    func toggle(open: @escaping () -> Void) {
        guard let window else {
            open()
            return
        }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    /// Hides the mini window without releasing it (the ✕ button).
    func hide() {
        window?.orderOut(nil)
    }
}

/// Transparent background view that hands its window to the manager once
/// attached — the same `NSViewRepresentable` pattern as the globe's scroll
/// wheel capture.
struct FloatingWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowGrabberView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowGrabberView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // Async: the window may still be mid-setup during the callback.
            DispatchQueue.main.async {
                FloatingWindowManager.shared.register(window)
            }
        }
    }
}

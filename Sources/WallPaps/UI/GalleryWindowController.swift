import AppKit
import SwiftUI

/// Lazily creates and shows the gallery/settings window for the menu-bar app,
/// switching the activation policy so the window can come to front (and back to
/// an accessory agent when closed).
@MainActor
final class GalleryWindowController: NSObject, NSWindowDelegate {
    static let shared = GalleryWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: MainWindowView())
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            win.setContentSize(NSSize(width: 940, height: 640))
            win.isReleasedWhenClosed = false
            // Immersive "gallery" chrome: transparent title bar over the dark wall.
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.backgroundColor = NSColor(red: 0.085, green: 0.08, blue: 0.085, alpha: 1)
            win.appearance = NSAppearance(named: .darkAqua)
            win.center()
            win.delegate = self
            window = win
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to a background agent (no Dock icon) once the window is closed.
        NSApp.setActivationPolicy(.accessory)
    }
}

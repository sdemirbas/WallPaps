import AppKit

/// Save-to-file and copy-to-clipboard for share images. (The gallery uses
/// SwiftUI's `ShareLink` for the system share sheet; the menu uses these.)
@MainActor
enum ShareManager {
    static func save(imageURL: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "WallPaps.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: imageURL, to: dest)
    }

    static func copyToClipboard(imageURL: URL) {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
}

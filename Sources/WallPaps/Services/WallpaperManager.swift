import AppKit

/// Sets the desktop wallpaper across one or more connected screens.
enum WallpaperManager {

    /// The 4K master canvas size that every artwork is archived at.
    static let masterCanvasSize = CGSize(width: 3840, height: 2160)

    @MainActor
    static func screens() -> [NSScreen] { NSScreen.screens }

    /// Native pixel size of a screen (points × backing scale).
    @MainActor
    static func pixelSize(of screen: NSScreen) -> CGSize {
        CGSize(width: (screen.frame.width * screen.backingScaleFactor).rounded(),
               height: (screen.frame.height * screen.backingScaleFactor).rounded())
    }

    /// Pixel size of the primary display, or 4K if none.
    @MainActor
    static func primaryCanvasPixelSize() -> CGSize {
        guard let screen = NSScreen.main else { return masterCanvasSize }
        return pixelSize(of: screen)
    }

    /// Apply `fileURL` as the wallpaper on a single screen.
    /// Note: macOS only updates the *current* Space.
    @MainActor
    static func setWallpaper(_ fileURL: URL, on screen: NSScreen) {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]
        try? NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: options)
    }
}

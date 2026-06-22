import SwiftUI
import AppKit

/// Process entry point. Supports a headless `--selftest` that exercises the
/// fetch + 4K render pipeline without launching the GUI or touching the desktop.
@main
enum Entry {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--selftest") {
            SelfTest.run() // never returns
        }
        if let i = args.firstIndex(of: "--makeicon"), i + 1 < args.count {
            IconGenerator.run(outputPath: args[i + 1]) // never returns
        }
        if let i = args.firstIndex(of: "--previewwelcome"), i + 1 < args.count {
            MainActor.assumeIsolated { WelcomePreview.render(to: args[i + 1]) } // never returns
        }
        if let i = args.firstIndex(of: "--shots"), i + 1 < args.count {
            ShotsGenerator.run(outDir: args[i + 1]) // never returns
        }
        WallPapsApp.main()
    }
}

/// Menu-bar (agent) app.
struct WallPapsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "photo.artframe")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Drives one-time startup once AppKit has finished launching.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // UpdaterService must be accessed early so SPUStandardUpdaterController
        // registers itself and can handle any Sparkle URL scheme callbacks.
        _ = UpdaterService.shared
        AppController.shared.start()
    }
}

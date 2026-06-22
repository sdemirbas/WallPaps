import Foundation
import Sparkle

/// Wraps SPUStandardUpdaterController and exposes Sparkle's update settings
/// to the SwiftUI layer via @Published + KVO bridging.
@MainActor
final class UpdaterService: ObservableObject {
    static let shared = UpdaterService()

    private let controller: SPUStandardUpdaterController
    private var observation: NSKeyValueObservation?

    /// Mirrors SPUUpdater.canCheckForUpdates so SwiftUI can disable menu items.
    @Published private(set) var canCheckForUpdates = false

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Bridge KVO → @Published (SPUUpdater is not Sendable, so capture by pointer)
        let updater = controller.updater
        observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] u, _ in
            let val = u.canCheckForUpdates
            Task { @MainActor [weak self] in self?.canCheckForUpdates = val }
        }
    }

    /// Opens the standard Sparkle "Check for Updates…" sheet.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: - Sparkle-managed settings (persisted by Sparkle in UserDefaults)

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }
}

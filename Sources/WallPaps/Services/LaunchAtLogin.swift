import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` to toggle "launch at login".
/// Only works for a properly bundled `.app` (built via Scripts/build-app.sh).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("WallPaps: launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}

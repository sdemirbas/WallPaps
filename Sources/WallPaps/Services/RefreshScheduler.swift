import Foundation

/// Low-energy periodic trigger built on `NSBackgroundActivityScheduler`, which
/// lets macOS coalesce/defer the work to save power instead of a tight timer.
final class RefreshScheduler {
    private var activity: NSBackgroundActivityScheduler?
    private let identifier = "com.local.wallpaps.refresh"
    private let onFire: @Sendable () -> Void

    init(onFire: @escaping @Sendable () -> Void) {
        self.onFire = onFire
    }

    /// (Re)start the scheduler with the given interval in seconds.
    func start(interval: TimeInterval) {
        activity?.invalidate()
        let activity = NSBackgroundActivityScheduler(identifier: identifier)
        activity.repeats = true
        activity.interval = interval
        // Generous tolerance => the OS batches our wake-up with other activity.
        activity.tolerance = max(60, interval * 0.25)
        activity.qualityOfService = .background
        activity.schedule { [onFire] completion in
            onFire()
            completion(.finished)
        }
        self.activity = activity
    }

    func stop() {
        activity?.invalidate()
        activity = nil
    }
}

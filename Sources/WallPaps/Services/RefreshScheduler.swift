import Foundation

/// Reliable periodic trigger using DispatchSourceTimer.
///
/// NSBackgroundActivityScheduler was replaced because macOS can defer it
/// aggressively (sometimes hours) under power-saving heuristics — unacceptable
/// for a user-configured wallpaper rotation interval.
final class RefreshScheduler {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.local.wallpaps.refresh", qos: .utility)
    private let onFire: @Sendable () -> Void

    init(onFire: @escaping @Sendable () -> Void) {
        self.onFire = onFire
    }

    /// (Re)start the scheduler with the given interval in seconds.
    func start(interval: TimeInterval) {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        // First fire after `interval`; leeway = 1% of interval, capped at 60 s.
        let leeway = DispatchTimeInterval.seconds(Int(min(60, interval * 0.01)))
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
        t.setEventHandler { [onFire] in onFire() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}

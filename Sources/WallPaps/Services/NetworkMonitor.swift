import Foundation
import Network

/// Lightweight connectivity watcher. Used to recover automatically when the
/// network comes back (e.g. the app launched offline).
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.local.wallpaps.network")
    private let lock = NSLock()
    private var _isOnline = true

    /// Called (on a background queue) when connectivity transitions to online.
    var onBecameOnline: (@Sendable () -> Void)?

    var isOnline: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isOnline
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = path.status == .satisfied
            self.lock.lock()
            let was = self._isOnline
            self._isOnline = online
            self.lock.unlock()
            if online && !was { self.onBecameOnline?() }
        }
        monitor.start(queue: queue)
    }
}

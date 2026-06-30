import AppKit

/// Auto-locks the vault on sleep / screen lock and after an idle timeout.
@MainActor
final class LockController {
    private let store: VaultStore
    private var idleTimer: Timer?

    /// Idle timeout in seconds; 0 disables idle auto-lock.
    var idleTimeout: TimeInterval {
        didSet { restartIdleTimer() }
    }

    init(store: VaultStore, idleTimeout: TimeInterval) {
        self.store = store
        self.idleTimeout = idleTimeout
        observeSystemEvents()
    }
    // ponytail: no deinit/removeObserver — this controller lives for the whole
    // process; observers die with it. Add cleanup only if it ever becomes transient.

    /// Call on any user activity (opening the dropdown, copying) to defer idle lock.
    func noteActivity() {
        restartIdleTimer()
    }

    private func observeSystemEvents() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.store.lock() }
            }
        }
    }

    private func restartIdleTimer() {
        idleTimer?.invalidate()
        guard idleTimeout > 0 else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.lock() }
        }
    }
}

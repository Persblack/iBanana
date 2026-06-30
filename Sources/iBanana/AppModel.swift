import SwiftUI
import VaultCore

/// Setting keys + defaults, shared by SettingsView (@AppStorage) and the
/// non-View consumers (lock timeout, clipboard clear).
enum SettingsKey {
    static let idleTimeout = "idleTimeoutSeconds"
    static let clipboardClear = "clipboardClearSeconds"

    static var idleTimeout_default: Double { 300 }
    static var clipboardClear_default: Double { 30 }

    static func register() {
        UserDefaults.standard.register(defaults: [
            idleTimeout: idleTimeout_default,
            clipboardClear: clipboardClear_default,
        ])
    }
    static var clipboardClearSeconds: TimeInterval {
        UserDefaults.standard.double(forKey: clipboardClear)
    }
    static var idleTimeoutSeconds: TimeInterval {
        UserDefaults.standard.double(forKey: idleTimeout)
    }
}

@MainActor
@Observable
final class AppModel {
    let store: VaultStore
    let lock: LockController

    init() {
        SettingsKey.register()
        let timeout = SettingsKey.idleTimeoutSeconds
        let keyStore = KeychainKeyStore(reuseDuration: timeout)
        let store = VaultStore(keyStore: keyStore)
        self.store = store
        self.lock = LockController(store: store, idleTimeout: timeout)
    }

    /// Open the dropdown → ensure unlocked (prompts Touch ID if needed).
    func onDropdownOpen() async {
        lock.idleTimeout = SettingsKey.idleTimeoutSeconds
        lock.noteActivity()
        if store.isLocked { await store.unlock() }
    }

    func copy(_ entry: Entry) {
        Clipboard.copy(entry.value, clearAfter: SettingsKey.clipboardClearSeconds)
        lock.noteActivity()
    }

    // Accessory (menubar-only) apps open windows behind everything and never
    // focus. Flip to .regular + activate so Manage/Settings actually appear,
    // and drop back to .accessory once the last one closes.
    private var managedWindowCount = 0

    func windowDidOpen() {
        managedWindowCount += 1
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowDidClose() {
        managedWindowCount = max(0, managedWindowCount - 1)
        if managedWindowCount == 0 {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}

import Foundation
import CryptoKit
import VaultCore

/// Owns the in-RAM vault and all disk I/O. `vault == nil` means locked.
@MainActor
@Observable
final class VaultStore {
    enum State: Equatable {
        case locked
        case unlocked
        case decryptError   // file present but undecryptable → offer import
    }

    private(set) var state: State = .locked
    private(set) var vault: Vault = Vault()
    var lastError: String?

    private let keyStore: KeyStore
    private var masterKey: SymmetricKey?

    init(keyStore: KeyStore) {
        self.keyStore = keyStore
    }

    var isLocked: Bool { state != .unlocked }

    // MARK: - File location

    private static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iBanana", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("vault.dat")
    }

    // MARK: - Lifecycle

    /// Triggers Touch ID (via the key store), then decrypts. Missing file → fresh
    /// empty vault. Undecryptable file → `.decryptError` (no silent data loss).
    func unlock() {
        lastError = nil
        do {
            let key = try keyStore.loadOrCreateMasterKey()
            masterKey = key
            let url = Self.fileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                vault = Vault()
                state = .unlocked
                return
            }
            let data = try Data(contentsOf: url)
            do {
                let loaded = try VaultCrypto.open(data, using: key)
                guard loaded.schemaVersion <= Vault.currentSchemaVersion else {
                    lastError = "This vault was written by a newer version. Update iBanana to open it."
                    state = .decryptError   // read-only refusal, no blind overwrite
                    return
                }
                vault = loaded
                state = .unlocked
            } catch {
                lastError = "Could not decrypt your data. Restore from a passphrase export."
                state = .decryptError
            }
        } catch {
            // Touch ID cancelled/failed, or key missing.
            lastError = "Unlock failed. Authenticate with Touch ID to continue."
            state = .locked
        }
    }

    func lock() {
        vault = Vault()
        masterKey = nil
        state = .locked
    }

    // MARK: - Mutations (each saves)

    func add(_ entry: Entry) {
        vault.entries.append(entry)
        save()
    }

    func update(_ entry: Entry) {
        guard let idx = vault.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var e = entry
        e.updatedAt = Date()
        vault.entries[idx] = e
        save()
    }

    func delete(_ id: UUID) {
        vault.entries.removeAll { $0.id == id }
        save()
    }

    /// Replace or merge (by id) an imported vault, then re-key locally.
    func applyImport(_ imported: Vault, merge: Bool) {
        if merge {
            var byId = Dictionary(vault.entries.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            for e in imported.entries { byId[e.id] = e }
            vault.entries = Array(byId.values).sorted { $0.createdAt < $1.createdAt }
        } else {
            vault.entries = imported.entries
        }
        // New device key after import (spec: import generates a fresh local masterKey).
        let newKey = SymmetricKey(size: .bits256)
        try? keyStore.replaceMasterKey(with: newKey)
        masterKey = newKey
        save()
    }

    func save() {
        guard let masterKey else { return }
        do {
            let data = try VaultCrypto.seal(vault, using: masterKey)
            try data.write(to: Self.fileURL, options: [.atomic])
        } catch {
            lastError = "Could not save your data."   // generic, no values leaked
        }
    }

    func exportData(passphrase: String) throws -> Data {
        try ExportCrypto.export(vault, passphrase: passphrase)
    }
}

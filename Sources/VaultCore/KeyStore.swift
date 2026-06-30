import Foundation
import CryptoKit

/// Abstracts the master-key store so the crypto/lifecycle logic is testable
/// without real Keychain or biometrics. The real implementation
/// (`KeychainKeyStore`, in the app target) gates `loadOrCreateMasterKey`
/// behind Touch ID.
public protocol KeyStore: Sendable {
    /// Returns the existing master key, creating + persisting a random one on
    /// first use. The real impl triggers the OS Touch-ID prompt here.
    func loadOrCreateMasterKey() throws -> SymmetricKey
    /// Replaces the master key (used after an import).
    func replaceMasterKey(with key: SymmetricKey) throws
    func deleteMasterKey() throws
}

/// In-memory fake for tests — no OS, no biometrics.
public final class InMemoryKeyStore: KeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var key: SymmetricKey?

    public init(initial: SymmetricKey? = nil) {
        self.key = initial
    }

    public func loadOrCreateMasterKey() throws -> SymmetricKey {
        lock.lock(); defer { lock.unlock() }
        if let key { return key }
        let new = SymmetricKey(size: .bits256)
        key = new
        return new
    }

    public func replaceMasterKey(with key: SymmetricKey) throws {
        lock.lock(); defer { lock.unlock() }
        self.key = key
    }

    public func deleteMasterKey() throws {
        lock.lock(); defer { lock.unlock() }
        key = nil
    }
}

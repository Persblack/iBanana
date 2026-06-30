import Foundation
import CryptoKit

/// Abstracts the master-key store so the crypto/lifecycle logic is testable
/// without real Keychain or biometrics. The real implementation
/// (`KeychainKeyStore`, in the app target) gates `loadOrCreateMasterKey`
/// behind Touch ID.
public protocol KeyStore: Sendable {
    /// Returns the existing master key, creating + persisting a random one on
    /// first use. The real impl triggers the OS Touch-ID prompt here (async so
    /// the prompt never blocks the main thread).
    func loadOrCreateMasterKey() async throws -> SymmetricKey
    /// Replaces the master key (used after an import).
    func replaceMasterKey(with key: SymmetricKey) throws
    func deleteMasterKey() throws
}

/// In-memory fake for tests — no OS, no biometrics. ponytail: no locking; tests
/// drive it single-threaded.
public final class InMemoryKeyStore: KeyStore, @unchecked Sendable {
    private var key: SymmetricKey?

    public init(initial: SymmetricKey? = nil) {
        self.key = initial
    }

    public func loadOrCreateMasterKey() async throws -> SymmetricKey {
        if let key { return key }
        let new = SymmetricKey(size: .bits256)
        key = new
        return new
    }

    public func replaceMasterKey(with key: SymmetricKey) throws {
        self.key = key
    }

    public func deleteMasterKey() throws {
        key = nil
    }
}

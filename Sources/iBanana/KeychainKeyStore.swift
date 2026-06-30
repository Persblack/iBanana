import Foundation
import CryptoKit
import LocalAuthentication
import VaultCore

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case biometryUnavailable
    case authFailed
}

/// Stores the 256-bit master key in a device-local Keychain item and gates
/// access behind an explicit Touch-ID prompt (`LAContext.evaluatePolicy`).
///
/// Why not `.biometryCurrentSet` Secure-Enclave key withholding (the stronger
/// design in the spec)? That requires the `keychain-access-groups` entitlement,
/// which needs signing with a paid Apple Developer team — `SecItemAdd` returns
/// `errSecMissingEntitlement (-34018)` for an ad-hoc / unsigned build. This
/// approach runs for everyone: the key is `WhenUnlockedThisDeviceOnly` and never
/// released to the UI until biometrics succeed. The boundary is your macOS
/// login + Touch ID — exactly the spec's stated threat model.
final class KeychainKeyStore: KeyStore, @unchecked Sendable {
    private let service = "com.ricoklatte.iBanana"
    private let account = "masterKey"

    func loadOrCreateMasterKey() async throws -> SymmetricKey {
        try await authenticate()
        if let existing = try loadKey() { return existing }
        let new = SymmetricKey(size: .bits256)
        try storeKey(new)
        return new
    }

    func replaceMasterKey(with key: SymmetricKey) throws {
        try? deleteMasterKey()
        try storeKey(key)
    }

    func deleteMasterKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Biometric gate

    /// Biometrics only (no password fallback): faithful to "needs YOUR
    /// fingerprint, even if someone else sits at your unlocked Mac." If Touch ID
    /// is unavailable/failing, recovery is the passphrase import path.
    ///
    /// A fresh `LAContext` per call — and thus a Touch-ID prompt — on every
    /// unlock. `unlock()` only runs from a locked state, so reusing a context
    /// (`touchIDAuthenticationAllowableReuseDuration`) would let a reopen within
    /// the reuse window silently bypass an idle auto-lock. No reuse = no bypass.
    private func authenticate() async throws {
        let ctx = LAContext()
        var policyError: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            throw KeychainError.biometryUnavailable
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your iBanana vault"
            ) { success, error in
                if success { cont.resume() }
                else { cont.resume(throwing: error ?? KeychainError.authFailed) }
            }
        }
    }

    // MARK: - Keychain (plain, device-local — no entitlement needed)

    private func loadKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func storeKey(_ key: SymmetricKey) throws {
        try? deleteMasterKey()   // overwrite any prior item
        let data = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }
}

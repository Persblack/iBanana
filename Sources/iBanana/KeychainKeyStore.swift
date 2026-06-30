import Foundation
import CryptoKit
import LocalAuthentication
import VaultCore

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case accessControlFailed
    case biometryUnavailable
}

/// Stores the 256-bit master key in the Keychain behind a biometric gate.
/// Reading the key triggers the OS Touch-ID prompt automatically; without a
/// successful match the key is never released and `vault.dat` stays opaque.
final class KeychainKeyStore: KeyStore {
    private let service = "com.ricoklatte.iBanana"
    private let account = "masterKey"

    /// LAContext reuse window so not every click re-prompts for a fingerprint.
    private let reuseDuration: TimeInterval

    init(reuseDuration: TimeInterval = 300) {
        self.reuseDuration = reuseDuration
    }

    func loadOrCreateMasterKey() throws -> SymmetricKey {
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

    // MARK: - Keychain primitives

    private func context() -> LAContext {
        let ctx = LAContext()
        ctx.touchIDAuthenticationAllowableReuseDuration = reuseDuration
        return ctx
    }

    private func loadKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context(),
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
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw KeychainError.accessControlFailed
        }
        let data = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }
}

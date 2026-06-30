import Foundation
import CryptoKit

public enum VaultCryptoError: Error, Equatable {
    case decryptionFailed
    case encodingFailed
}

/// Symmetric AES-GCM seal/open for the on-disk vault. Pure: no OS, no UI.
public enum VaultCrypto {
    public static func seal(_ vault: Vault, using key: SymmetricKey) throws -> Data {
        let json = try JSONEncoder().encode(vault)
        let sealed = try AES.GCM.seal(json, using: key)
        // .combined (nonce + ciphertext + tag) is non-nil for the default 12-byte nonce.
        guard let combined = sealed.combined else { throw VaultCryptoError.encodingFailed }
        return combined
    }

    public static func open(_ data: Data, using key: SymmetricKey) throws -> Vault {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let json = try AES.GCM.open(box, using: key)
            return try JSONDecoder().decode(Vault.self, from: json)
        } catch {
            throw VaultCryptoError.decryptionFailed
        }
    }
}

import Foundation
import CryptoKit
import CommonCrypto

public enum ExportCryptoError: Error, Equatable {
    case importFailed          // wrong passphrase, corrupt envelope, or decode error
    case unsupportedVersion
    case randomFailed
}

/// Passphrase-protected envelope for device migration. CryptoKit has no PBKDF2,
/// so the key derivation uses CommonCrypto (stdlib). Pure: no OS UI, no Keychain.
public enum ExportCrypto {
    public static let currentVersion = 1
    public static let defaultIterations = 600_000   // OWASP 2023 floor for PBKDF2-HMAC-SHA256

    struct Envelope: Codable {
        var version: Int
        var salt: Data
        var iterations: Int
        var ciphertext: Data   // AES.GCM combined (nonce + ct + tag)
    }

    public static func export(
        _ vault: Vault,
        passphrase: String,
        iterations: Int = defaultIterations
    ) throws -> Data {
        let salt = try randomBytes(16)
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let combined = try VaultCrypto.seal(vault, using: key)
        let envelope = Envelope(
            version: currentVersion,
            salt: salt,
            iterations: iterations,
            ciphertext: combined
        )
        return try JSONEncoder().encode(envelope)
    }

    public static func `import`(_ data: Data, passphrase: String) throws -> Vault {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ExportCryptoError.importFailed
        }
        guard envelope.version == currentVersion else { throw ExportCryptoError.unsupportedVersion }
        let key = try deriveKey(
            passphrase: passphrase,
            salt: envelope.salt,
            iterations: envelope.iterations
        )
        do {
            return try VaultCrypto.open(envelope.ciphertext, using: key)
        } catch {
            // Wrong passphrase derives the wrong key → GCM tag mismatch.
            throw ExportCryptoError.importFailed
        }
    }

    // MARK: - Primitives

    static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let passwordData = Data(passphrase.utf8)
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                passwordData.withUnsafeBytes { pwPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr.baseAddress, passwordData.count,
                        saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedPtr.bindMemory(to: UInt8.self).baseAddress, 32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw ExportCryptoError.importFailed }
        return SymmetricKey(data: derived)
    }

    static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw ExportCryptoError.randomFailed
        }
        return Data(bytes)
    }
}

import Testing
import Foundation
import CryptoKit
@testable import VaultCore

private func sampleVault() -> Vault {
    Vault(entries: [
        Entry(title: "Geschäfts-IBAN", value: "DE00 1234 5678 9012 3456 78", category: "Steuer"),
        Entry(title: "Notiz", value: "Zeile 1\nZeile 2", category: nil, masked: false),
    ])
}

@Test func vaultRoundTrip() throws {
    let key = SymmetricKey(size: .bits256)
    let vault = sampleVault()
    let sealed = try VaultCrypto.seal(vault, using: key)
    let opened = try VaultCrypto.open(sealed, using: key)
    #expect(opened == vault)
}

@Test func wrongKeyFails() throws {
    let sealed = try VaultCrypto.seal(sampleVault(), using: SymmetricKey(size: .bits256))
    #expect(throws: VaultCryptoError.decryptionFailed) {
        try VaultCrypto.open(sealed, using: SymmetricKey(size: .bits256))
    }
}

@Test func corruptBytesThrowCleanly() throws {
    let key = SymmetricKey(size: .bits256)
    var sealed = try VaultCrypto.seal(sampleVault(), using: key)
    sealed[sealed.count - 1] ^= 0xFF   // flip a tag byte
    #expect(throws: VaultCryptoError.decryptionFailed) {
        try VaultCrypto.open(sealed, using: key)
    }
}

@Test func garbageDataThrows() {
    let key = SymmetricKey(size: .bits256)
    #expect(throws: VaultCryptoError.decryptionFailed) {
        try VaultCrypto.open(Data([0x00, 0x01, 0x02]), using: key)
    }
}

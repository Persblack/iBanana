import Testing
import Foundation
@testable import VaultCore

private func sampleVault() -> Vault {
    Vault(entries: [Entry(title: "IBAN", value: "DE00 1234", category: "Steuer")])
}

@Test func exportImportRoundTrip() throws {
    // Low iteration count keeps the test fast; production uses the default 600k.
    let vault = sampleVault()
    let data = try ExportCrypto.export(vault, passphrase: "correct horse", iterations: 1_000)
    let opened = try ExportCrypto.import(data, passphrase: "correct horse")
    #expect(opened == vault)
}

@Test func wrongPassphraseFails() throws {
    let data = try ExportCrypto.export(sampleVault(), passphrase: "right", iterations: 1_000)
    #expect(throws: ExportCryptoError.importFailed) {
        try ExportCrypto.import(data, passphrase: "wrong")
    }
}

@Test func corruptEnvelopeThrows() throws {
    var data = try ExportCrypto.export(sampleVault(), passphrase: "pw", iterations: 1_000)
    data[data.count / 2] ^= 0xFF
    #expect(throws: (any Error).self) {
        try ExportCrypto.import(data, passphrase: "pw")
    }
}

@Test func nonEnvelopeDataThrows() {
    #expect(throws: ExportCryptoError.importFailed) {
        try ExportCrypto.import(Data("not json".utf8), passphrase: "pw")
    }
}

@Test func saltIsRandomPerExport() throws {
    let a = try ExportCrypto.export(sampleVault(), passphrase: "pw", iterations: 1_000)
    let b = try ExportCrypto.export(sampleVault(), passphrase: "pw", iterations: 1_000)
    #expect(a != b)   // different salt + nonce → different ciphertext
}

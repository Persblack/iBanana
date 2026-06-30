import Testing
import Foundation
import CryptoKit
@testable import VaultCore

@Test func inMemoryKeyStoreIsStable() throws {
    let store = InMemoryKeyStore()
    let a = try store.loadOrCreateMasterKey()
    let b = try store.loadOrCreateMasterKey()
    #expect(a == b)   // same key across calls
}

@Test func replaceChangesKey() throws {
    let store = InMemoryKeyStore()
    let original = try store.loadOrCreateMasterKey()
    let replacement = SymmetricKey(size: .bits256)
    try store.replaceMasterKey(with: replacement)
    #expect(try store.loadOrCreateMasterKey() == replacement)
    #expect(try store.loadOrCreateMasterKey() != original)
}

@Test func deleteRegeneratesFreshKey() throws {
    let store = InMemoryKeyStore()
    let original = try store.loadOrCreateMasterKey()
    try store.deleteMasterKey()
    #expect(try store.loadOrCreateMasterKey() != original)
}

/// A key round-trips a vault end to end through the store.
@Test func keyFromStoreSealsAndOpens() throws {
    let store = InMemoryKeyStore()
    let key = try store.loadOrCreateMasterKey()
    let vault = Vault(entries: [Entry(title: "t", value: "v")])
    let sealed = try VaultCrypto.seal(vault, using: key)
    #expect(try VaultCrypto.open(sealed, using: key) == vault)
}

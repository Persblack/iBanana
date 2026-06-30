import Testing
import Foundation
import CryptoKit
@testable import VaultCore

@Test func inMemoryKeyStoreIsStable() async throws {
    let store = InMemoryKeyStore()
    let a = try await store.loadOrCreateMasterKey()
    let b = try await store.loadOrCreateMasterKey()
    #expect(a == b)   // same key across calls
}

@Test func replaceChangesKey() async throws {
    let store = InMemoryKeyStore()
    let original = try await store.loadOrCreateMasterKey()
    let replacement = SymmetricKey(size: .bits256)
    try store.replaceMasterKey(with: replacement)
    #expect(try await store.loadOrCreateMasterKey() == replacement)
    #expect(try await store.loadOrCreateMasterKey() != original)
}

@Test func deleteRegeneratesFreshKey() async throws {
    let store = InMemoryKeyStore()
    let original = try await store.loadOrCreateMasterKey()
    try store.deleteMasterKey()
    #expect(try await store.loadOrCreateMasterKey() != original)
}

/// A key round-trips a vault end to end through the store.
@Test func keyFromStoreSealsAndOpens() async throws {
    let store = InMemoryKeyStore()
    let key = try await store.loadOrCreateMasterKey()
    let vault = Vault(entries: [Entry(title: "t", value: "v")])
    let sealed = try VaultCrypto.seal(vault, using: key)
    #expect(try VaultCrypto.open(sealed, using: key) == vault)
}

# iBanana 🍌

A macOS menubar vault for personal snippets (IBAN, tax number, notes). Click the
menubar banana → Touch-ID-gated dropdown → click an entry to copy it. Everything
is AES-GCM encrypted on disk; nothing leaves the device. No server, no account,
no cloud.

## Build & run

```sh
swift build           # compile
swift test            # run the crypto-core unit tests
swift run iBanana      # launch (menubar-only app)
```

Requires macOS 14+, Swift 6.2 / Xcode 26+. No external dependencies.

> **Touch ID / Keychain:** the biometric gate needs a code-signed app. Running
> the raw `swift run` binary may not present the Touch-ID prompt or persist the
> Keychain item correctly — open `Package.swift` in Xcode and run a signed build
> for the full unlock flow. The crypto core (`VaultCore`) is fully exercised by
> `swift test` without any of that.

## Layout

- `Sources/VaultCore/` — pure, OS-free library: `Vault`/`Entry` models,
  `VaultCrypto` (AES-GCM seal/open), `ExportCrypto` (PBKDF2 passphrase envelope),
  `KeyStore` protocol + in-memory fake. All unit-tested.
- `Sources/iBanana/` — the SwiftUI app: `MenuBarExtra` dropdown, manage/settings
  windows, lock lifecycle, clipboard auto-clear, and `KeychainKeyStore`
  (Keychain + `.biometryCurrentSet` Touch ID).
- `docs/` — design spec and implementation plan.

## Design

See [`docs/2026-06-30-menubar-vault-design.md`](docs/2026-06-30-menubar-vault-design.md).

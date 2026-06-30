# CLAUDE.md

## What this is
iBanana 🍌 — a macOS menubar vault for personal snippets (IBAN, tax number, notes). Click the menubar icon → Touch-ID-gated dropdown → click an entry to copy it. Local-only, no server/account/cloud. Personal tool for Rico, open source. Design done (`docs/2026-06-30-menubar-vault-design.md`), not yet implemented.

## Stack & commands
SwiftUI `MenuBarExtra` (macOS 14+), single Xcode/SwiftPM app, no external deps. CryptoKit (AES-GCM), Keychain + `SecAccessControl(.biometryCurrentSet)`, LocalAuthentication, PBKDF2 (CommonCrypto) for export/import.
Build/test commands: TBD once the Xcode/SwiftPM project exists.

## Project-specific rules
- Security boundary is macOS login + Touch ID; no multi-user.
- `masterKey` is device-local (`ThisDeviceOnly`, non-exportable) by design — device migration goes through the passphrase-protected export/import path only.
- Never log entry values; report errors generically.
- Crypto core (`seal`/`open`, PBKDF2 export/import) stays a pure function, no UI/OS; Keychain/Touch ID behind a `KeyStore` protocol so tests use an in-memory fake.

## Active team
None installed yet. Roles intentionally not used.

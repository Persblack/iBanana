# iBanana 🍌

A macOS menubar vault for personal snippets (IBAN, tax number, notes). Click the
menubar banana → Touch-ID-gated dropdown → click an entry to copy it. Everything
is AES-GCM encrypted on disk; nothing leaves the device. No server, no account,
no cloud.

## Install (download)

Grab `iBanana-x.y.z-macos.zip` from the [latest release](https://github.com/Persblack/iBanana/releases/latest),
unzip, and move `iBanana.app` to `/Applications`. The build is **Apple Silicon
(arm64)** and ad-hoc signed (no paid Apple Developer account), so Gatekeeper
quarantines it on first launch. Clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/iBanana.app
open /Applications/iBanana.app
```

Prefer not to trust a prebuilt binary? Build it yourself — it's a few seconds:

## Build & run

```sh
swift build           # compile
swift test            # run the crypto-core unit tests
swift run iBanana      # launch (menubar-only app)
```

Requires macOS 14+, Swift 6.2 / Xcode 26+. No external dependencies.

### Install as a menubar app

```sh
scripts/make-app.sh    # build release, wrap in iBanana.app, ad-hoc sign, install to /Applications
open /Applications/iBanana.app
```

> **Touch ID:** the master key lives in a device-local Keychain item gated by an
> explicit `LAContext` biometric prompt. This works with the ad-hoc signing the
> script does — no Apple Developer account needed. The stronger
> `.biometryCurrentSet` Secure-Enclave key-withholding from the design spec
> requires the `keychain-access-groups` entitlement (paid dev-team signing); see
> the note in `Sources/iBanana/KeychainKeyStore.swift`. The crypto core
> (`VaultCore`) is fully exercised by `swift test` regardless.

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

# iBanana Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A macOS menubar vault (`MenuBarExtra`) for personal snippets, Touch-ID-gated, AES-GCM encrypted on disk, with passphrase export/import for device migration.

**Architecture:** A SwiftPM package with two targets. `VaultCore` is a pure, OS-free library (models + AES-GCM seal/open + PBKDF2 export/import + a `KeyStore` protocol) that is fully unit-testable without UI or biometrics. `iBanana` is the SwiftUI executable (MenuBarExtra, manage/settings windows, lock lifecycle, clipboard auto-clear, and the real `KeychainKeyStore` backed by Keychain + Touch ID). The split keeps every security-critical function testable.

**Tech Stack:** Swift 6.2, SwiftUI `MenuBarExtra` (macOS 14+), CryptoKit (`AES.GCM`, `SymmetricKey`), CommonCrypto (PBKDF2), Keychain + `SecAccessControl(.biometryCurrentSet)`, LocalAuthentication.

## Global Constraints

- macOS 14+ deployment target; no external dependencies (stdlib/system frameworks only).
- `masterKey` is device-local (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) and non-exportable — migration is passphrase-only.
- Never log entry values; errors are generic.
- Crypto core has no UI/OS coupling; Keychain/Touch ID sit behind `KeyStore` (in-memory fake in tests).
- `schemaVersion` checked on load; unknown-higher → read-only, no blind overwrite.

---

### Task 1: Package + VaultCore models

**Files:** `Package.swift`, `Sources/VaultCore/Models.swift`

- `Entry` (`id, title, value, category?, createdAt, updatedAt`) and `Vault` (`entries, schemaVersion`), both `Codable`. `currentSchemaVersion = 1`.
- Package: library `VaultCore`, executable `iBanana` (depends on VaultCore), test target `VaultCoreTests`. Platform `.macOS(.v14)`.

### Task 2: VaultCrypto (symmetric seal/open) — TESTED

**Files:** `Sources/VaultCore/VaultCrypto.swift`, `Tests/VaultCoreTests/VaultCryptoTests.swift`

- `seal(_ vault, using: SymmetricKey) -> Data` (JSON → `AES.GCM.seal` → `.combined`).
- `open(_ data, using: SymmetricKey) -> Vault` (combined → `AES.GCM.open` → decode).
- Tests: round-trip equality; wrong key throws; corrupt bytes throw cleanly.

### Task 3: ExportCrypto (PBKDF2 passphrase envelope) — TESTED

**Files:** `Sources/VaultCore/ExportCrypto.swift`, `Tests/VaultCoreTests/ExportCryptoTests.swift`

- `ExportEnvelope { version, salt, iterations, ciphertext }` (Codable JSON).
- `export(_ vault, passphrase, iterations=600_000)`: random 16-byte salt (`SecRandomCopyBytes`), PBKDF2-HMAC-SHA256 → 32-byte key → `AES.GCM.seal` → envelope JSON.
- `import(_ data, passphrase) -> Vault`: decode envelope → PBKDF2 → `AES.GCM.open`.
- Tests: round-trip; wrong passphrase throws; truncated/corrupt envelope throws.

### Task 4: KeyStore protocol + in-memory fake + KeychainKeyStore

**Files:** `Sources/VaultCore/KeyStore.swift`, `Sources/iBanana/KeychainKeyStore.swift`, `Tests/VaultCoreTests/KeyStoreTests.swift`

- Protocol: `loadOrCreateMasterKey() throws -> SymmetricKey`, `replaceMasterKey(with:) throws`, `deleteMasterKey() throws`.
- `InMemoryKeyStore` (in VaultCore, for tests): generates+caches a key.
- `KeychainKeyStore` (in app): `.biometryCurrentSet` access control, `WhenUnlockedThisDeviceOnly`; load triggers the OS Touch-ID prompt.
- Test the in-memory fake's create/replace/delete semantics.

### Task 5: VaultStore (disk I/O + lock state)

**Files:** `Sources/iBanana/VaultStore.swift`

- `@MainActor @Observable` model. Holds `vault` (nil = locked), `isLocked`.
- `unlock()`: `keyStore.loadOrCreateMasterKey()` → read `vault.dat` → `VaultCrypto.open` (missing file → empty vault; decrypt fail → surfaced error + import offer). `schemaVersion` guard.
- `save()`: `VaultCrypto.seal` → atomic write to `~/Library/Application Support/iBanana/vault.dat`.
- `lock()`: drop in-RAM vault. CRUD helpers stamp `updatedAt` and save.
- `LAContext` reuse window (`touchIDAuthenticationAllowableReuseDuration = 300`).

### Task 6: Lock lifecycle + clipboard

**Files:** `Sources/iBanana/LockController.swift`, `Sources/iBanana/Clipboard.swift`

- Auto-lock on `NSWorkspace` sleep/screen-lock notifications and idle timeout (default 300s, configurable).
- `Clipboard.copy(_ value, clearAfter:)`: write to `NSPasteboard`, schedule clear (default 30s) — clear only if pasteboard still holds the same value.

### Task 7: UI — three surfaces

**Files:** `Sources/iBanana/iBananaApp.swift`, `Sources/iBanana/DropdownView.swift`, `Sources/iBanana/ManageView.swift`, `Sources/iBanana/SettingsView.swift`

- `@main` `MenuBarExtra` (banana icon); `NSApp.setActivationPolicy(.accessory)`.
- Dropdown: locked → "🔒 Unlock with Touch ID"; unlocked → search field + grouped, masked (`••••••`) entries, click copies + ✓; "+ New" / "Manage".
- Manage window: add/edit/delete (title, multiline value, optional category).
- Settings: idle timeout, clipboard-clear seconds, per-entry mask toggle, Export, Import (replace/merge by `id`).

### Task 8: Build, test, verify

- `swift build` and `swift test` green. Document the manual-only paths (Touch ID, Keychain, menubar interaction) that can't run headless.

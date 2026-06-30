# Menüleisten-Tresor — Design-Spec

**Datum:** 2026-06-30
**Name:** *iBanana* 🍌
**Status:** Design, noch nicht implementiert
**Zweck:** Persönliches Werkzeug für Rico, Open Source auf GitHub.

## Was es ist

Eine macOS-Menüleisten-App. Klick auf das Symbol oben → Dropdown mit den eigenen
Schnipseln (IBAN, Steuernummer, Notizen …). Klick auf einen Eintrag → Wert ist in der
Zwischenablage. Vor dem ersten Anzeigen pro Sitzung: ein Touch-ID-Tap. Alles liegt
verschlüsselt auf der Platte und ist bei Gerätewechsel exportier-/importierbar.

Kein Server, kein Account, keine Cloud. Ein lokales Tool, das das „durch-Ordner-klicken"
abschafft.

## Nicht-Ziele (bewusst weggelassen)

- Keine Sync über mehrere Geräte (dafür gibt es Export/Import).
- Keine Kategorien-Hierarchie/Ordner — flache, durchsuchbare Liste plus *eine* optionale
  Kategorie pro Eintrag reicht.
- Keine Passwort-Generierung, kein Autofill in Browsern, kein iOS-Companion. (YAGNI —
  später nachrüstbar, falls je gewünscht.)
- Kein Multi-User. Die Sicherheitsgrenze ist dein macOS-Login + Touch ID.

## Stack

| Bereich          | Wahl                                              | Warum |
|------------------|---------------------------------------------------|-------|
| UI               | SwiftUI `MenuBarExtra` (macOS 14+)                | Native Menüleisten-App, kein Fremdcode |
| Krypto           | CryptoKit (`AES.GCM`, `SymmetricKey`)             | Apple-Standard, authentifizierte Verschlüsselung |
| Schlüssel-Ablage | Keychain + `SecAccessControl(.biometryCurrentSet)`| Touch-ID-Gate, Secure-Enclave-gestützt |
| Biometrie        | LocalAuthentication (`LAContext`)                 | Touch-ID-Prompt + Wiederverwendungsfenster |
| Passphrase-KDF   | PBKDF2 (CommonCrypto) für Export/Import           | CryptoKit hat kein PBKDF2; CommonCrypto ist Stdlib |

Eine einzelne Swift-Package-/Xcode-App, keine externen Dependencies.

## Datenmodell

```swift
struct Entry: Codable, Identifiable {
    let id: UUID
    var title: String        // "Geschäfts-IBAN"
    var value: String        // mehrzeilig erlaubt (auch längere Notizen)
    var category: String?    // optional, z.B. "Steuer" — nur zum Gruppieren
    var createdAt: Date
    var updatedAt: Date
}

struct Vault: Codable {       // genau das, was verschlüsselt auf Platte landet
    var entries: [Entry]
    var schemaVersion: Int    // für spätere Migrationen
}
```

Ein Eintrag deckt sowohl kurze Felder (IBAN) als auch mehrzeilige Notizen ab — `value`
ist einfach ein String. Kein zweites Modell nötig.

## Verschlüsselung — wie es konkret läuft

```
                    Keychain (Touch-ID-Gate)
                    ┌───────────────────────┐
   Touch ID  ─────► │  masterKey (32 Byte)  │
                    └──────────┬────────────┘
                               │ entsperrt
                               ▼
   vault.dat  ──►  AES-GCM-Decrypt  ──►  Vault (im RAM)  ──►  Dropdown
   (Platte)        (nonce + tag in Datei)
```

1. **Erstinstallation:** App erzeugt einen zufälligen `masterKey` (`SymmetricKey(size: .bits256)`)
   und legt ihn in der Keychain ab — mit Access-Control `.biometryCurrentSet` und
   `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (synct nicht in iCloud, bleibt auf dem Gerät).
2. **Speichern:** `Vault` → JSON → `AES.GCM.seal(json, using: masterKey)` →
   `combined`-Bytes (nonce + ciphertext + tag) → Datei `vault.dat` in
   `~/Library/Application Support/iBanana/`.
3. **Entsperren (pro Sitzung):** Beim ersten Dropdown-Öffnen liest die App den `masterKey`
   aus der Keychain — das OS zeigt **automatisch** den Touch-ID-Prompt. Erfolg → Datei
   entschlüsseln → Einträge anzeigen.
4. **`LAContext`-Wiederverwendung:** `touchIDAuthenticationAllowableReuseDuration` (z.B. 5 min),
   damit nicht jeder Klick einen neuen Fingerabdruck verlangt.

`.biometryCurrentSet` heißt: ändern sich die hinterlegten Fingerabdrücke, wird der Zugriff
ungültig — dann greift der Import-Pfad (siehe unten) zur Wiederherstellung.

## Sperren / Entsperren-Lebenszyklus

- **Entsperrt** nach erfolgreichem Touch ID, für die Dauer des Wiederverwendungsfensters.
- **Sperrt automatisch** bei: System-Sleep / Bildschirmsperre (`NSWorkspace`-Notifications),
  App-Beenden, und nach konfigurierbarem Idle-Timeout (Default 5 min).
- Im gesperrten Zustand zeigt das Dropdown nur „🔒 Mit Touch ID entsperren".

## Touch ID erzwingen — auch wenn jemand anderes am Mac sitzt

Genau dafür ist `.biometryCurrentSet` + automatischer OS-Prompt da: Der `masterKey` wird
**nur** nach erfolgreicher Biometrie herausgegeben. Ohne deinen Fingerabdruck (oder dein
Geräte-Passwort als Fallback, falls `.userPresence` statt `.biometryCurrentSet`) bleibt die
Datei undurchdringlicher Ciphertext. Ein anderer Nutzer an deinem entsperrten Login sieht
nichts.

## Export / Import (Gerätewechsel)

Der `masterKey` ist gerätelokal (`ThisDeviceOnly`) und nicht exportierbar — das ist Absicht.
Für den Umzug gibt es einen separaten, **passphrasen**-geschützten Pfad:

- **Export:** Nutzer gibt eine Passphrase ein → PBKDF2(Passphrase, zufälliges Salt, hohe
  Iterationszahl) → abgeleiteter Schlüssel → `AES.GCM.seal(vaultJSON)` →
  Datei `ibanana-export.dat` (enthält Salt + nonce + ciphertext + tag, Version-Header).
- **Import:** Datei wählen → Passphrase → PBKDF2 → entschlüsseln → in den lokalen Vault
  übernehmen, **neuen** lokalen `masterKey` erzeugen. Konflikt-Handling: „Ersetzen" oder
  „Zusammenführen" (per `id`).

Damit hängt der Umzug an etwas, das du im Kopf hast (Passphrase), nicht an einem Schlüssel,
der das Gerät nie verlässt.

## UI-Flächen (genau drei)

1. **Menüleisten-Dropdown:** Suchfeld oben; darunter Einträge (nach Kategorie gruppiert,
   wenn gesetzt). Klick → Wert kopiert, kurzes ✓-Feedback. Oben Aktion „+ Neu" und „Verwalten".
2. **Verwalten-Fenster:** Liste mit Hinzufügen/Bearbeiten/Löschen. Felder: Titel, Wert
   (mehrzeilig), Kategorie (optional).
3. **Einstellungen:** Idle-Timeout, „Zwischenablage nach N Sekunden leeren" (optional, gut bei
   sensiblen Werten), Export, Import.

## Sicherheits-Feinheiten (billig, lohnt sich)

- **Zwischenablage automatisch leeren** N Sekunden nach dem Kopieren eines Eintrags (Default an,
  z.B. 30 s) — verhindert, dass die IBAN ewig in der Pasteboard-History liegt.
- **Werte in der Liste maskiert** (`••••••`) bis zum Klick — Schulterblick-Schutz. Optional pro
  Eintrag abschaltbar (z.B. für reine Notizen).
- **Keine Werte in Logs.** Fehler nur generisch melden.

## Fehlerbehandlung

- Touch ID abgebrochen/fehlgeschlagen → Dropdown bleibt gesperrt, klare Meldung, kein Crash.
- `vault.dat` fehlt/korrupt → leeren Vault anlegen statt abstürzen; bei Entschlüsselungsfehler
  Hinweis „Daten konnten nicht entschlüsselt werden" + Import-Angebot (statt stillem Datenverlust).
- Keychain-Schlüssel weg (z.B. Fingerabdrücke geändert) → Hinweis + Import-Pfad anbieten.
- Schema-Migration: `schemaVersion` prüfen; unbekannt-höher → schreibgeschützt warnen statt
  blind überschreiben.

## Testbarkeit

- Krypto-Kern (`seal`/`open` von `Vault`, PBKDF2-Export/Import) ist reine Funktion ohne UI/OS —
  Unit-Tests: round-trip (verschlüsseln→entschlüsseln == Original), falsche Passphrase schlägt
  fehl, korrupte Bytes werfen sauber.
- Keychain/Touch ID hinter ein schmales Protokoll (`KeyStore`) legen → in Tests durch
  In-Memory-Fake ersetzbar, ohne echte Biometrie.

## Offene Kleinigkeiten (vor Implementierung entscheidbar, kein Blocker)

- App-Symbol (eine Banane bietet sich an 🍌).
- Globaler Hotkey zum Öffnen des Dropdowns? (Nice-to-have, später.)
- Mindest-macOS-Version final (14 vs. 15).
```

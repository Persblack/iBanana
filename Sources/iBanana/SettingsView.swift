import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @AppStorage(SettingsKey.idleTimeout) private var idleTimeout = SettingsKey.idleTimeout_default
    @AppStorage(SettingsKey.clipboardClear) private var clipboardClear = SettingsKey.clipboardClear_default

    @State private var passphrase = ""
    @State private var status: String?

    var body: some View {
        Form {
            Section("Locking") {
                Picker("Idle auto-lock", selection: $idleTimeout) {
                    Text("1 min").tag(60.0)
                    Text("5 min").tag(300.0)
                    Text("15 min").tag(900.0)
                    Text("Never").tag(0.0)
                }
                .onChange(of: idleTimeout) { _, new in model.lock.idleTimeout = new }
            }

            Section("Clipboard") {
                Picker("Clear clipboard after", selection: $clipboardClear) {
                    Text("10 s").tag(10.0)
                    Text("30 s").tag(30.0)
                    Text("60 s").tag(60.0)
                    Text("Never").tag(0.0)
                }
            }

            Section("Migration") {
                SecureField("Export passphrase", text: $passphrase)
                HStack {
                    Button("Export…") { exportVault() }
                        .disabled(passphrase.isEmpty || model.store.isLocked)
                    Button("Import…") { importVault() }
                        .disabled(passphrase.isEmpty)
                }
                if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func exportVault() {
        do {
            let data = try model.store.exportData(passphrase: passphrase)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "ibanana-export.dat"
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url, options: [.atomic])
                status = "Exported."
            }
        } catch {
            status = "Export failed."
        }
    }

    private func importVault() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let imported = try ExportCrypto.import(data, passphrase: passphrase)
            // Default to merge by id; replace would discard local-only entries.
            model.store.applyImport(imported, merge: true)
            status = "Imported \(imported.entries.count) entr\(imported.entries.count == 1 ? "y" : "ies")."
        } catch {
            status = "Import failed — wrong passphrase or corrupt file."
        }
    }
}

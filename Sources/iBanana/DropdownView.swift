import SwiftUI
import AppKit
import VaultCore

/// The menubar dropdown: locked gate, or search + grouped entries.
struct DropdownView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    @State private var search = ""
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.store.isLocked {
                lockedView
            } else {
                unlockedView
            }
        }
        .padding(10)
        .frame(width: 300)
        .task { await model.onDropdownOpen() }
    }

    // MARK: - Locked

    private var lockedView: some View {
        VStack(spacing: 10) {
            Text("🔒 Unlock with Touch ID")
                .font(.headline)
            if let err = model.store.lastError {
                Text(err).font(.caption).foregroundStyle(.secondary)
            }
            Button("Unlock") { Task { await model.store.unlock() } }
                .keyboardShortcut(.defaultAction)
            if model.store.state == .decryptError {
                Button("Import from export…") { show("settings") }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Unlocked

    private var unlockedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)

            if filtered.isEmpty {
                Text(model.store.vault.entries.isEmpty ? "No entries yet." : "No matches.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(grouped, id: \.0) { group, entries in
                            if let group {
                                Text(group).font(.caption.bold()).foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                            ForEach(entries) { entry in
                                row(entry)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Divider()
            HStack {
                Button("+ New") { show("manage") }
                Spacer()
                Button("Manage") { show("manage") }
                Button("Settings") { show("settings") }
            }
            .font(.caption)
        }
    }

    private func row(_ entry: Entry) -> some View {
        Button {
            model.copy(entry)
            copiedID = entry.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if copiedID == entry.id { copiedID = nil }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title).fontWeight(.medium)
                    Text(entry.masked ? "••••••" : preview(entry.value))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if copiedID == entry.id {
                    Image(systemName: "checkmark").foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    // MARK: - Derivations

    private var filtered: [Entry] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.store.vault.entries }
        return model.store.vault.entries.filter {
            $0.title.lowercased().contains(q)
                || ($0.category?.lowercased().contains(q) ?? false)
        }
    }

    /// Grouped by category (nil group first), each preserving entry order.
    private var grouped: [(String?, [Entry])] {
        let groups = Dictionary(grouping: filtered) { $0.category?.isEmpty == false ? $0.category : nil }
        return groups.sorted { ($0.key ?? "") < ($1.key ?? "") }
    }

    private func preview(_ value: String) -> String {
        value.split(separator: "\n").first.map(String.init) ?? value
    }

    /// Open a managed window with the app brought to the foreground.
    private func show(_ id: String) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }
}

import SwiftUI
import VaultCore

/// Add / edit / delete entries.
struct ManageView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: UUID?
    @State private var draft: Entry?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(model.store.vault.entries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.title).fontWeight(.medium)
                        if let cat = entry.category, !cat.isEmpty {
                            Text(cat).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(entry.id)
                }
            }
            .frame(minWidth: 200)
            .toolbar {
                Button {
                    let new = Entry(title: "New entry", value: "")
                    draft = new
                    selection = new.id
                } label: { Image(systemName: "plus") }
            }
        } detail: {
            if let id = selection,
               let entry = (draft?.id == id ? draft : model.store.vault.entries.first { $0.id == id }) {
                editor(for: entry)
            } else {
                Text("Select or add an entry.").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
    }

    @ViewBuilder
    private func editor(for entry: Entry) -> some View {
        Form {
            TextField("Title", text: binding(entry, \.title))
            TextField("Category (optional)", text: binding(entry, \.category, default: ""))
            Toggle("Mask value in list", isOn: binding(entry, \.masked))
            Section("Value") {
                TextEditor(text: binding(entry, \.value))
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
            }
            HStack {
                Button("Save") { commit(entry) }
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Delete", role: .destructive) {
                    model.store.delete(entry.id)
                    if draft?.id == entry.id { draft = nil }
                    selection = nil
                }
            }
        }
        .padding()
    }

    // MARK: - Editing helpers
    // Edits mutate a draft copy in place; Save persists it.

    private func binding<V>(_ entry: Entry, _ keyPath: WritableKeyPath<Entry, V>) -> Binding<V> {
        Binding(
            get: { current(entry)[keyPath: keyPath] },
            set: { var e = current(entry); e[keyPath: keyPath] = $0; draft = e }
        )
    }

    private func binding(_ entry: Entry, _ keyPath: WritableKeyPath<Entry, String?>, default def: String) -> Binding<String> {
        Binding(
            get: { current(entry)[keyPath: keyPath] ?? def },
            set: { var e = current(entry); e[keyPath: keyPath] = $0.isEmpty ? nil : $0; draft = e }
        )
    }

    private func current(_ entry: Entry) -> Entry {
        if let draft, draft.id == entry.id { return draft }
        return entry
    }

    private func commit(_ entry: Entry) {
        let e = current(entry)
        if model.store.vault.entries.contains(where: { $0.id == e.id }) {
            model.store.update(e)
        } else {
            model.store.add(e)
        }
        draft = nil
    }
}

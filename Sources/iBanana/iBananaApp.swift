import SwiftUI

@main
struct iBananaApp: App {
    @State private var model = AppModel()

    init() {
        // Menubar-only: no Dock icon, no main window.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            DropdownView()
                .environment(model)
        } label: {
            Text("🍌")
        }
        .menuBarExtraStyle(.window)

        Window("Manage", id: "manage") {
            ManageView().environment(model)
        }
        .defaultSize(width: 600, height: 400)

        Window("Settings", id: "settings") {
            SettingsView().environment(model)
        }
        .defaultSize(width: 420, height: 360)
    }
}

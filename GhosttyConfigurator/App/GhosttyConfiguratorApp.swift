import SwiftUI

@main
struct GhosttyConfiguratorApp: App {
    @State private var store = ConfigStore()
    @State private var schemaStore = SchemaStore.shared

    init() {
        // Kick off schema introspection at app startup so DocTooltip is ready
        // by the time the user clicks an info button. Detached so the App
        // init can return immediately.
        Task.detached(priority: .userInitiated) {
            await SchemaStore.shared.loadIfNeeded()
        }
    }

    var body: some Scene {
        // Empty window title so each pane's hero card is the only identity in
        // the toolbar area. Window menu still shows "Ghostty Configurator"
        // (via INFOPLIST CFBundleName) so window-switching/Dock labels stay
        // correct.
        let scene = Window("", id: "main") {
            ContentView()
                .environment(store)
                .environment(schemaStore)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {}
        }

        // Always present the window at launch, even if a prior session left
        // it closed. macOS 15+ — older systems just fall through.
        if #available(macOS 15.0, *) {
            return scene.defaultLaunchBehavior(.presented)
        } else {
            return scene
        }
    }
}

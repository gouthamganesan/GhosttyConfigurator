import SwiftUI

@main
struct GhosttyConfiguratorApp: App {
    @State private var store = ConfigStore()
    @State private var schemaStore = SchemaStore.shared

    var body: some Scene {
        let scene = Window("Ghostty Configurator", id: "main") {
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

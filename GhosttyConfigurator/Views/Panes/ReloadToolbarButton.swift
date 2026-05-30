import SwiftUI

/// Toolbar button placed on every pane that sends `reload_config` to Ghostty
/// via `GhosttyReloader`. Disabled (with a tooltip explaining why) when
/// Ghostty isn't running or installed.
struct ReloadToolbarButton: View {
    @Environment(ConfigStore.self) private var store
    @State private var lastError: String?
    @State private var showErrorAlert: Bool = false

    var body: some View {
        Button {
            Task {
                do {
                    try await GhosttyReloader.reload()
                } catch let error as GhosttyReloader.ReloadError {
                    lastError = error.description
                    showErrorAlert = true
                } catch {
                    lastError = String(describing: error)
                    showErrorAlert = true
                }
            }
        } label: {
            Label("Reload Ghostty", systemImage: "arrow.clockwise")
        }
        .help(helpText)
        .disabled(!store.ghosttyInstalled)
        .alert(
            "Couldn't reload Ghostty",
            isPresented: $showErrorAlert,
            presenting: lastError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error +
                "\n\nThe configurator wrote your changes to the config file. To apply them, focus Ghostty and press ⌘⇧, manually.")
        }
    }

    private var helpText: String {
        if !store.ghosttyInstalled {
            return "Install Ghostty to enable reload."
        }
        return "Reload Ghostty's config (⌘⇧,)"
    }
}

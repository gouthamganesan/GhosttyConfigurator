import SwiftUI

/// Toolbar button placed on every pane that sends `reload_config` to Ghostty
/// via `GhosttyReloader`. Disabled (with a tooltip explaining why) when
/// Ghostty isn't running or installed.
struct ReloadToolbarButton: View {
    @Environment(ConfigStore.self) private var store
    @State private var lastError: String?
    @State private var showFailureSheet: Bool = false
    @State private var isRestarting: Bool = false

    var body: some View {
        Button {
            Task {
                do {
                    try await GhosttyReloader.reload()
                } catch let error as GhosttyReloader.ReloadError {
                    lastError = error.description
                    showFailureSheet = true
                } catch {
                    lastError = String(describing: error)
                    showFailureSheet = true
                }
            }
        } label: {
            Label("Reload Ghostty", systemImage: "arrow.clockwise")
        }
        .help(helpText)
        .disabled(!store.ghosttyInstalled)
        .sheet(isPresented: $showFailureSheet) {
            failureSheet
        }
    }

    private var failureSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Couldn't reload Ghostty", systemImage: "exclamationmark.triangle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let lastError {
                    Text(lastError)
                        .foregroundStyle(.secondary)
                }
                Text("Your changes were written to the config file.")
                if store.ghosttyInstalled {
                    Text("Restart Ghostty to apply them, or focus Ghostty and press ⌘⇧, manually.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Once Ghostty is running, focus it and press ⌘⇧, to apply them.")
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    showFailureSheet = false
                }
                .keyboardShortcut(.cancelAction)

                if store.ghosttyInstalled {
                    Button {
                        restart()
                    } label: {
                        if isRestarting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Restart Ghostty")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isRestarting)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func restart() {
        isRestarting = true
        Task {
            do {
                try await GhosttyReloader.restart()
                isRestarting = false
                showFailureSheet = false
            } catch let error as GhosttyReloader.ReloadError {
                lastError = error.description
                isRestarting = false
            } catch {
                lastError = String(describing: error)
                isRestarting = false
            }
        }
    }

    private var helpText: String {
        if !store.ghosttyInstalled {
            return "Install Ghostty to enable reload."
        }
        return "Reload Ghostty's config (⌘⇧,)"
    }
}

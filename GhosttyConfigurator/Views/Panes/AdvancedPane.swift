import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A3 — Advanced pane. v0 ships **Profile management** only, which is the
/// configurator's headline differentiator over Ghostty's eventual native
/// UI (Plan §3.4). Quick Terminal, custom shaders, splits, links land in
/// follow-up passes (A3b/c).
struct AdvancedPane: View {
    @Environment(ConfigStore.self) private var store

    @State private var newProfileName: String = ""
    @State private var showNewProfileSheet: Bool = false
    @State private var newProfileError: String?

    var body: some View {
        @Bindable var store = store
        return Form {
            profilesSection
            quickTerminalSection(store: store)
            actionsSection
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "Advanced",
            subtitle: "Profile stacking, plus the rest of Ghostty's advanced surface."
        )
        .sheet(isPresented: $showNewProfileSheet) {
            newProfileSheet
        }
    }

    // MARK: - Sections

    private var profilesSection: some View {
        Section {
            if store.profiles.isEmpty {
                emptyState
            } else {
                ForEach(store.profiles) { profile in
                    profileRow(profile)
                }
            }
        } header: {
            HStack {
                Text("Profiles")
                Spacer()
                Menu {
                    Button("Add existing file…") { pickExistingProfile() }
                    Button("Create new profile…") {
                        newProfileName = ""
                        newProfileError = nil
                        showNewProfileSheet = true
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        } footer: {
            Text(
                "Profiles are `config-file = ?path` includes — Ghostty applies them in order; later overrides earlier. Drag-reorder is via the ↑↓ controls."
            )
        }
    }

    private func quickTerminalSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
            LabeledContent {
                Picker("", selection: $store.quickTerminalPosition) {
                    ForEach(QuickTerminalPosition.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            } label: {
                rowLabel(
                    "Position",
                    modified: store.quickTerminalPosition != .top,
                    docKey: "quick-terminal-position"
                )
            }

            LabeledContent {
                Picker("", selection: $store.quickTerminalScreen) {
                    ForEach(QuickTerminalScreen.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            } label: {
                rowLabel(
                    "Screen",
                    modified: store.quickTerminalScreen != .main,
                    docKey: "quick-terminal-screen"
                )
            }

            LabeledContent {
                Picker("", selection: $store.quickTerminalSpaceBehavior) {
                    ForEach(QuickTerminalSpaceBehavior.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            } label: {
                rowLabel(
                    "Across Spaces",
                    modified: store.quickTerminalSpaceBehavior != .move,
                    docKey: "quick-terminal-space-behavior"
                )
            }

            LabeledContent {
                Stepper(
                    value: $store.quickTerminalAnimationDuration,
                    in: 0 ... 2,
                    step: 0.05
                ) {
                    Text(String(format: "%.2f s", store.quickTerminalAnimationDuration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } label: {
                rowLabel(
                    "Animation duration",
                    modified: store.quickTerminalAnimationDuration != 0.2,
                    docKey: "quick-terminal-animation-duration"
                )
            }

            Toggle(isOn: $store.quickTerminalAutohide) {
                rowLabel(
                    "Auto-hide on focus loss",
                    modified: !store.quickTerminalAutohide,
                    docKey: "quick-terminal-autohide"
                )
            }
        } header: {
            Text("Quick Terminal")
        } footer: {
            Text(
                "The quick terminal is a slide-out drop-down. It needs a hotkey — bind `toggle_quick_terminal` in **Keyboard → Add Shortcut**; there's no default binding."
            )
        }
    }

    private var actionsSection: some View {
        Section {
            LabeledContent {
                Button("Open in editor") {
                    store.openActiveConfig()
                }
            } label: {
                rowLabel(
                    "Active config file",
                    modified: false,
                    docKey: nil
                )
                Text(prettyPath(store.fileURL))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } header: {
            Text("Active config")
        }
    }

    // MARK: - Row helpers

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No profiles yet")
                .foregroundStyle(.secondary)
            Text(
                "Add a profile to layer settings on top of your base config — e.g. a work palette, a CTF font setup, a presentation theme."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button("Add existing file…") { pickExistingProfile() }
                Button("Create new profile…") {
                    newProfileName = ""
                    newProfileError = nil
                    showNewProfileSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func profileRow(_ profile: Profile) -> some View {
        let resolved = profile.resolvedURL(relativeTo: store.fileURL)
        let exists = FileManager.default.fileExists(atPath: resolved.path)

        return HStack(spacing: 12) {
            Image(systemName: exists ? "doc.text.fill" : "doc.text")
                .foregroundStyle(exists ? Color.accentColor : Color.orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.body.weight(.medium))
                Text(prettyPath(resolved))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !exists {
                    Text("File not found — Ghostty will skip this include silently.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Button {
                    store.moveProfile(profile, direction: .up)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Apply earlier (lower priority)")

                Button {
                    store.moveProfile(profile, direction: .down)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Apply later (higher priority)")

                Button {
                    if exists {
                        NSWorkspace.shared.open(resolved)
                    } else {
                        NSWorkspace.shared.activateFileViewerSelecting([resolved])
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("Open in editor")

                Button(role: .destructive) {
                    store.removeProfile(profile)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove from active config (file stays on disk)")
            }
        }
        .padding(.vertical, 4)
    }

    private var newProfileSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New profile").font(.headline)
            Text(
                "Creates `\(prettyPath(store.fileURL.deletingLastPathComponent()))/profiles/<name>.ghostty` and adds it to your active config."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createProfile() }

            if let newProfileError {
                Label(newProfileError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { showNewProfileSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { createProfile() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: - Actions

    private func pickExistingProfile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a Ghostty config file to include"
        panel.allowedContentTypes = [.text, .plainText].compactMap { $0 }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.addProfile(at: url.path)
    }

    private func createProfile() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let url = try store.createEmptyProfile(named: name)
            store.addProfile(at: url.path)
            showNewProfileSheet = false
            newProfileName = ""
        } catch {
            newProfileError = String(describing: error)
        }
    }

    private func prettyPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var path = url.path
        if path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }
        return path
    }
}

import SwiftUI

struct ShellPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $store.shellIntegration) {
                        ForEach(ShellIntegration.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Integration",
                        modified: store.isModified(\.shellIntegration, default: store.defaults.shellIntegration),
                        docKey: "shell-integration"
                    )
                }

                Toggle(isOn: $store.shellFeatureCursor) {
                    rowLabel(
                        "Update cursor shape",
                        modified: store.shellFeatureCursor != store.defaults.shellFeatureCursor,
                        docKey: "shell-integration-features (cursor)"
                    )
                }

                Toggle(isOn: $store.shellFeatureSudo) {
                    rowLabel(
                        "Quote arguments to sudo",
                        modified: store.shellFeatureSudo != store.defaults.shellFeatureSudo,
                        docKey: "shell-integration-features (sudo)"
                    )
                }

                Toggle(isOn: $store.shellFeatureTitle) {
                    rowLabel(
                        "Update window title from shell",
                        modified: store.shellFeatureTitle != store.defaults.shellFeatureTitle,
                        docKey: "shell-integration-features (title)"
                    )
                }

                Toggle(isOn: $store.shellFeatureSshEnv) {
                    rowLabel(
                        "Forward SSH environment",
                        modified: store.shellFeatureSshEnv != store.defaults.shellFeatureSshEnv,
                        docKey: "shell-integration-features (ssh-env)"
                    )
                }

                Toggle(isOn: $store.shellFeatureSshTerminfo) {
                    rowLabel(
                        "Install terminfo on SSH",
                        modified: store.shellFeatureSshTerminfo != store.defaults.shellFeatureSshTerminfo,
                        docKey: "shell-integration-features (ssh-terminfo)"
                    )
                }
            } header: {
                Text("Integration")
            } footer: {
                Text(
                    "**SSH environment** rewrites TERM from `xterm-ghostty` → `xterm-256color` over SSH and forwards COLORTERM. **Install terminfo on SSH** copies Ghostty's terminfo entry to the remote host so it doesn't need to be pre-installed."
                )
            }

            Section {
                LabeledContent {
                    TextField("", text: $store.shellCommand, prompt: Text("Use login shell"))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                } label: {
                    rowLabel(
                        "Command",
                        modified: store.isModified(\.shellCommand, default: store.defaults.shellCommand),
                        docKey: "command"
                    )
                }

                LabeledContent {
                    TextField("", text: $store.initialCommand, prompt: Text("First launch only"))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                } label: {
                    rowLabel(
                        "Initial command",
                        modified: !store.initialCommand.isEmpty,
                        docKey: "initial-command"
                    )
                }

                LabeledContent {
                    TextField("", text: $store.workingDirectory, prompt: Text("Inherit"))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                } label: {
                    rowLabel(
                        "Working directory",
                        modified: store.isModified(\.workingDirectory, default: store.defaults.workingDirectory),
                        docKey: "working-directory"
                    )
                }
            } header: {
                Text("Startup")
            } footer: {
                Text(
                    "**Command** replaces your login shell for every surface. **Initial command** only runs on the first surface — useful for launching a TUI on startup without affecting later splits/tabs."
                )
            }

            Section {
                EnvVarsEditor()
            } header: {
                Text("Environment Variables")
            } footer: {
                Text(
                    "Passed to commands launched in terminal surfaces. Setting a key to an empty value removes it from the inherited environment."
                )
            }

            Section {
                LabeledContent {
                    TextField("", text: $store.term)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                } label: {
                    rowLabel(
                        "TERM",
                        modified: store.isModified(\.term, default: store.defaults.term),
                        docKey: "term"
                    )
                }
            } header: {
                Text("Terminal")
            } footer: {
                Text(
                    "`xterm-ghostty` enables Ghostty's terminfo features. Change only if a remote host doesn't have it installed."
                )
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "Shell",
            subtitle: "Integration, startup, environment, TERM."
        )
    }
}

// MARK: - Environment variables editor

private struct EnvVarsEditor: View {
    @Environment(ConfigStore.self) private var store
    @State private var draft: [EnvVar] = []
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 6) {
                ForEach($draft) { $row in
                    HStack(spacing: 6) {
                        TextField("KEY", text: $row.key, prompt: Text("KEY"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 140)
                            .onSubmit(commit)
                        Text("=").foregroundStyle(.tertiary)
                        TextField("value", text: $row.value, prompt: Text("value"))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commit)
                        Button {
                            draft.removeAll { $0.id == row.id }
                            commit()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this variable")
                        .accessibilityLabel("Remove variable")
                    }
                }
                HStack {
                    Button {
                        draft.append(EnvVar())
                    } label: {
                        Label("Add variable", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    if !draft.isEmpty {
                        Button("Apply", action: commit)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.top, 6)
        } label: {
            rowLabel(
                labelTitle,
                modified: !store.envVars.isEmpty,
                docKey: "env"
            )
        }
        .onAppear { syncFromStore() }
        .onChange(of: store.envVars) { _, _ in
            // External edit (or undo) — refresh local draft if the user hasn't
            // started editing this session.
            syncFromStore()
        }
    }

    private var labelTitle: String {
        let count = store.envVars.count
        if count == 0 { return "Environment variables" }
        return "Environment variables (\(count))"
    }

    private func syncFromStore() {
        draft = store.envVars
    }

    private func commit() {
        store.envVars = draft.filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
        // Refresh ids from the store so future diffs are stable.
        syncFromStore()
    }
}

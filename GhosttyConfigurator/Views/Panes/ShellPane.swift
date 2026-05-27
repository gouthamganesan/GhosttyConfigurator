import SwiftUI

struct ShellPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                HeroCard(
                    symbol: "terminal.fill",
                    title: "Shell",
                    description: "Shell integration features, startup command, and TERM identity.",
                    iconGradient: [.gray, Color(NSColor.systemGray)]
                )
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.shellIntegration) {
                        ForEach(ShellIntegration.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Integration",
                             modified: store.isModified(\.shellIntegration, default: store.defaults.shellIntegration),
                             docKey: "shell-integration")
                }

                Toggle(isOn: $store.shellFeatureCursor) {
                    rowLabel("Update cursor shape",
                             modified: store.shellFeatureCursor != store.defaults.shellFeatureCursor,
                             docKey: "shell-integration-features (cursor)")
                }

                Toggle(isOn: $store.shellFeatureSudo) {
                    rowLabel("Quote arguments to sudo",
                             modified: store.shellFeatureSudo != store.defaults.shellFeatureSudo,
                             docKey: "shell-integration-features (sudo)")
                }

                Toggle(isOn: $store.shellFeatureTitle) {
                    rowLabel("Update window title from shell",
                             modified: store.shellFeatureTitle != store.defaults.shellFeatureTitle,
                             docKey: "shell-integration-features (title)")
                }
            } header: {
                Text("Integration")
            } footer: {
                Text("Integration enables features like \"jump to last prompt\", current-directory tracking, and cursor-style switching in vi.")
            }

            Section {
                LabeledContent {
                    TextField("", text: $store.shellCommand, prompt: Text("Use login shell"))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                } label: {
                    rowLabel("Command",
                             modified: store.isModified(\.shellCommand, default: store.defaults.shellCommand),
                             docKey: "command")
                }

                LabeledContent {
                    TextField("", text: $store.workingDirectory, prompt: Text("Inherit"))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                } label: {
                    rowLabel("Working directory",
                             modified: store.isModified(\.workingDirectory, default: store.defaults.workingDirectory),
                             docKey: "working-directory")
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Leave Command blank to use your login shell. Working directory uses the launching process's CWD if unset.")
            }

            Section {
                LabeledContent {
                    TextField("", text: $store.term)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                } label: {
                    rowLabel("TERM",
                             modified: store.isModified(\.term, default: store.defaults.term),
                             docKey: "term")
                }
            } header: {
                Text("Terminal")
            } footer: {
                Text("`xterm-ghostty` enables Ghostty's terminfo features. Change only if a remote host doesn't have it installed.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shell")
    }
}

import SwiftUI

struct ClipboardAndMousePane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                HeroCard(
                    symbol: "doc.on.clipboard.fill",
                    title: "Clipboard & Mouse",
                    description: "Pasting permissions, selection behavior, and mouse capture rules.",
                    iconGradient: [.green, .mint]
                )
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.clipboardRead) {
                        ForEach(ClipboardPermission.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Allow reading clipboard",
                             modified: store.isModified(\.clipboardRead, default: store.defaults.clipboardRead),
                             docKey: "clipboard-read")
                }

                LabeledContent {
                    Picker("", selection: $store.clipboardWrite) {
                        ForEach(ClipboardPermission.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Allow writing clipboard",
                             modified: store.isModified(\.clipboardWrite, default: store.defaults.clipboardWrite),
                             docKey: "clipboard-write")
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Terminal apps can attempt to read or write your system clipboard. Asking is the safe default — allow only if you know what you're running.")
            }

            Section {
                Toggle(isOn: $store.clipboardPasteProtection) {
                    rowLabel("Paste protection",
                             modified: store.isModified(\.clipboardPasteProtection, default: store.defaults.clipboardPasteProtection),
                             docKey: "clipboard-paste-protection")
                }

                Toggle(isOn: $store.clipboardTrimTrailingSpaces) {
                    rowLabel("Trim trailing spaces on paste",
                             modified: store.isModified(\.clipboardTrimTrailingSpaces, default: store.defaults.clipboardTrimTrailingSpaces),
                             docKey: "clipboard-trim-trailing-spaces")
                }
            } header: {
                Text("Paste")
            } footer: {
                Text("Paste protection asks before pasting content with newlines or control characters — common phishing vector via copied terminal commands.")
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.copyOnSelect) {
                        ForEach(CopyOnSelect.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Copy on select",
                             modified: store.isModified(\.copyOnSelect, default: store.defaults.copyOnSelect),
                             docKey: "copy-on-select")
                }

                Toggle(isOn: $store.selectionClearOnTyping) {
                    rowLabel("Clear selection when typing",
                             modified: store.isModified(\.selectionClearOnTyping, default: store.defaults.selectionClearOnTyping),
                             docKey: "selection-clear-on-typing")
                }
            } header: {
                Text("Selection")
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.mouseShiftCapture) {
                        ForEach(MouseShiftCapture.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Shift capture",
                             modified: store.isModified(\.mouseShiftCapture, default: store.defaults.mouseShiftCapture),
                             docKey: "mouse-shift-capture")
                }

                LabeledContent {
                    Stepper(value: $store.mouseScrollMultiplier, in: 0.1...10, step: 0.1) {
                        Text(String(format: "%.1f×", store.mouseScrollMultiplier))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel("Scroll multiplier",
                             modified: store.isModified(\.mouseScrollMultiplier, default: store.defaults.mouseScrollMultiplier),
                             docKey: "mouse-scroll-multiplier")
                }

                Toggle(isOn: $store.mouseReporting) {
                    rowLabel("Forward mouse events to apps",
                             modified: store.isModified(\.mouseReporting, default: store.defaults.mouseReporting),
                             docKey: "mouse-reporting")
                }

                Toggle(isOn: $store.focusFollowsMouse) {
                    rowLabel("Focus follows mouse",
                             modified: store.isModified(\.focusFollowsMouse, default: store.defaults.focusFollowsMouse),
                             docKey: "focus-follows-mouse")
                }
            } header: {
                Text("Mouse")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Clipboard & Mouse")
    }
}

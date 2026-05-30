import SwiftUI

struct ClipboardAndMousePane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $store.clipboardRead) {
                        ForEach(ClipboardPermission.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Allow reading clipboard",
                        modified: store.isModified(\.clipboardRead, default: store.defaults.clipboardRead),
                        docKey: "clipboard-read"
                    )
                }

                LabeledContent {
                    Picker("", selection: $store.clipboardWrite) {
                        ForEach(ClipboardPermission.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Allow writing clipboard",
                        modified: store.isModified(\.clipboardWrite, default: store.defaults.clipboardWrite),
                        docKey: "clipboard-write"
                    )
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text(
                    "Terminal apps can attempt to read or write your system clipboard. Asking is the safe default — allow only if you know what you're running."
                )
            }

            Section {
                Toggle(isOn: $store.clipboardPasteProtection) {
                    rowLabel(
                        "Paste protection",
                        modified: store.isModified(
                            \.clipboardPasteProtection,
                            default: store.defaults.clipboardPasteProtection
                        ),
                        docKey: "clipboard-paste-protection"
                    )
                }

                Toggle(isOn: $store.clipboardPasteBracketedSafe) {
                    rowLabel(
                        "Trust bracketed pastes",
                        modified: store.isModified(
                            \.clipboardPasteBracketedSafe,
                            default: store.defaults.clipboardPasteBracketedSafe
                        ),
                        docKey: "clipboard-paste-bracketed-safe"
                    )
                }

                Toggle(isOn: $store.clipboardTrimTrailingSpaces) {
                    rowLabel(
                        "Trim trailing spaces on paste",
                        modified: store.isModified(
                            \.clipboardTrimTrailingSpaces,
                            default: store.defaults.clipboardTrimTrailingSpaces
                        ),
                        docKey: "clipboard-trim-trailing-spaces"
                    )
                }
            } header: {
                Text("Paste")
            } footer: {
                Text(
                    "Paste protection asks before pasting content with newlines or control characters — common phishing vector via copied terminal commands. Bracketed-paste trust skips the prompt when the running program has explicitly opted into bracketed-paste mode (e.g. a shell with a properly configured prompt)."
                )
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.copyOnSelect) {
                        ForEach(CopyOnSelect.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Copy on select",
                        modified: store.isModified(\.copyOnSelect, default: store.defaults.copyOnSelect),
                        docKey: "copy-on-select"
                    )
                }

                Toggle(isOn: $store.selectionClearOnTyping) {
                    rowLabel(
                        "Clear selection when typing",
                        modified: store.isModified(
                            \.selectionClearOnTyping,
                            default: store.defaults.selectionClearOnTyping
                        ),
                        docKey: "selection-clear-on-typing"
                    )
                }

                Toggle(isOn: $store.selectionClearOnCopy) {
                    rowLabel(
                        "Clear selection after copy",
                        modified: store.isModified(
                            \.selectionClearOnCopy,
                            default: store.defaults.selectionClearOnCopy
                        ),
                        docKey: "selection-clear-on-copy"
                    )
                }

                DisclosureGroup("Word boundaries") {
                    LabeledContent {
                        TextField("", text: $store.selectionWordChars)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: 280)
                    } label: {
                        rowLabel(
                            "Characters",
                            modified: store.selectionWordChars != store.defaults.selectionWordChars,
                            docKey: "selection-word-chars"
                        )
                    }
                }
            } header: {
                Text("Selection")
            } footer: {
                Text(
                    "Word boundaries control where double-click selection stops. Default includes brackets, punctuation, and quoting characters — useful for selecting tokens in code."
                )
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.rightClickAction) {
                        ForEach(RightClickAction.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Right-click action",
                        modified: store.isModified(\.rightClickAction, default: store.defaults.rightClickAction),
                        docKey: "right-click-action"
                    )
                }

                LabeledContent {
                    Picker("", selection: $store.mouseShiftCapture) {
                        ForEach(MouseShiftCapture.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Shift capture",
                        modified: store.isModified(\.mouseShiftCapture, default: store.defaults.mouseShiftCapture),
                        docKey: "mouse-shift-capture"
                    )
                }

                LabeledContent {
                    Stepper(value: $store.mouseScrollMultiplier, in: 0.1 ... 10, step: 0.1) {
                        Text(String(format: "%.1f×", store.mouseScrollMultiplier))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel(
                        "Scroll multiplier",
                        modified: store.isModified(
                            \.mouseScrollMultiplier,
                            default: store.defaults.mouseScrollMultiplier
                        ),
                        docKey: "mouse-scroll-multiplier"
                    )
                }

                Toggle(isOn: $store.mouseReporting) {
                    rowLabel(
                        "Forward mouse events to apps",
                        modified: store.isModified(\.mouseReporting, default: store.defaults.mouseReporting),
                        docKey: "mouse-reporting"
                    )
                }

                Toggle(isOn: $store.focusFollowsMouse) {
                    rowLabel(
                        "Focus follows mouse",
                        modified: store.isModified(\.focusFollowsMouse, default: store.defaults.focusFollowsMouse),
                        docKey: "focus-follows-mouse"
                    )
                }
            } header: {
                Text("Mouse")
            }

            Section {
                LabeledContent {
                    Stepper(value: $store.scrollbackLimitMB, in: 1 ... 1000, step: 1) {
                        Text("\(Int(store.scrollbackLimitMB)) MB")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel(
                        "Buffer size",
                        modified: Int(store.scrollbackLimitMB * 1_000_000) != store.defaults.scrollbackLimitBytes,
                        docKey: "scrollback-limit"
                    )
                }

                LabeledContent {
                    Picker("", selection: $store.scrollbar) {
                        ForEach(Scrollbar.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Scrollbar",
                        modified: store.isModified(\.scrollbar, default: store.defaults.scrollbar),
                        docKey: "scrollbar"
                    )
                }

                Toggle(isOn: $store.scrollToBottomOnKeystroke) {
                    rowLabel(
                        "Jump to bottom on keystroke",
                        modified: store.scrollToBottomOnKeystroke != store.defaults.scrollToBottomOnKeystroke,
                        docKey: "scroll-to-bottom (keystroke)"
                    )
                }

                Toggle(isOn: $store.scrollToBottomOnOutput) {
                    rowLabel(
                        "Jump to bottom on new output",
                        modified: store.scrollToBottomOnOutput != store.defaults.scrollToBottomOnOutput,
                        docKey: "scroll-to-bottom (output)"
                    )
                }
            } header: {
                Text("Scrollback")
            } footer: {
                Text(
                    "Buffer size is per terminal surface; memory is allocated lazily up to this limit. Default is ~10 MB, which holds tens of thousands of lines of typical output."
                )
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "Clipboard & Mouse",
            subtitle: "Permissions, paste, selection, scrollback."
        )
    }
}

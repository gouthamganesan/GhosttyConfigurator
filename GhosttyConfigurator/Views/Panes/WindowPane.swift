import SwiftUI

struct WindowPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                HeroCard(
                    symbol: "macwindow",
                    title: "Window",
                    description: "Title-bar style, padding, and window-level behavior.",
                    iconGradient: [.blue, .cyan]
                )
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.titlebarStyle) {
                        ForEach(TitlebarStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Title bar style",
                             modified: store.isModified(\.titlebarStyle, default: store.defaults.titlebarStyle),
                             docKey: "macos-titlebar-style")
                }

                LabeledContent {
                    Picker("", selection: $store.macosWindowButtons) {
                        ForEach(MacosWindowButtons.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Window buttons",
                             modified: store.isModified(\.macosWindowButtons, default: store.defaults.macosWindowButtons),
                             docKey: "macos-window-buttons")
                }
            } header: {
                Text("Title Bar")
            } footer: {
                Text("Hiding the title bar uses the entire window for terminal contents. Traffic-light buttons stay accessible via menu-bar commands.")
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.windowDecoration) {
                        ForEach(WindowDecoration.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Decoration",
                             modified: store.isModified(\.windowDecoration, default: store.defaults.windowDecoration),
                             docKey: "window-decoration")
                }

                Toggle(isOn: $store.macosWindowShadow) {
                    rowLabel("Window shadow",
                             modified: store.isModified(\.macosWindowShadow, default: store.defaults.macosWindowShadow),
                             docKey: "macos-window-shadow")
                }
            } header: {
                Text("Appearance")
            }

            Section {
                LabeledContent {
                    Stepper(value: $store.windowPaddingX, in: 0...60, step: 1) {
                        Text("\(store.windowPaddingX) pt").monospacedDigit().foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel("Horizontal padding",
                             modified: store.isModified(\.windowPaddingX, default: store.defaults.windowPaddingX),
                             docKey: "window-padding-x")
                }

                LabeledContent {
                    Stepper(value: $store.windowPaddingY, in: 0...60, step: 1) {
                        Text("\(store.windowPaddingY) pt").monospacedDigit().foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel("Vertical padding",
                             modified: store.isModified(\.windowPaddingY, default: store.defaults.windowPaddingY),
                             docKey: "window-padding-y")
                }

                Toggle(isOn: $store.windowPaddingBalance) {
                    rowLabel("Balance padding",
                             modified: store.isModified(\.windowPaddingBalance, default: store.defaults.windowPaddingBalance),
                             docKey: "window-padding-balance")
                }
            } header: {
                Text("Padding")
            } footer: {
                Text("Balancing pads each terminal row evenly when the cell size doesn't divide the window cleanly.")
            }

            Section {
                Toggle(isOn: $store.macosNonNativeFullscreen) {
                    rowLabel("Non-native fullscreen",
                             modified: store.isModified(\.macosNonNativeFullscreen, default: store.defaults.macosNonNativeFullscreen),
                             docKey: "macos-non-native-fullscreen")
                }

                LabeledContent {
                    Picker("", selection: $store.windowSaveState) {
                        ForEach(WindowSaveState.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Restore windows",
                             modified: store.isModified(\.windowSaveState, default: store.defaults.windowSaveState),
                             docKey: "window-save-state")
                }
            } header: {
                Text("Behavior")
            } footer: {
                Text("Non-native fullscreen avoids the macOS animation but loses Spaces integration.")
            }
        }
        .formStyle(.grouped)
    }
}

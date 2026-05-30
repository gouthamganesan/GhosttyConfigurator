import SwiftUI

struct WindowPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
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

                LabeledContent {
                    Picker("", selection: $store.macosTitlebarProxyIcon) {
                        ForEach(MacosTitlebarProxyIcon.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Proxy icon",
                             modified: store.isModified(\.macosTitlebarProxyIcon, default: store.defaults.macosTitlebarProxyIcon),
                             docKey: "macos-titlebar-proxy-icon")
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        Text(store.windowTitleFontFamily.isEmpty
                                ? "System default"
                                : store.windowTitleFontFamily)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 160, alignment: .trailing)
                        FontPickerButton(
                            currentFamily: store.windowTitleFontFamily.isEmpty
                                ? store.fontFamily
                                : store.windowTitleFontFamily,
                            currentSize: store.fontSize
                        ) { family, _ in
                            store.windowTitleFontFamily = family
                        }
                        if !store.windowTitleFontFamily.isEmpty {
                            Button {
                                store.windowTitleFontFamily = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .help("Use the system default title font")
                        }
                    }
                } label: {
                    rowLabel("Title font",
                             modified: !store.windowTitleFontFamily.isEmpty,
                             docKey: "window-title-font-family")
                }
            } header: {
                Text("Title Bar")
            } footer: {
                Text("Hiding the title bar uses the entire window for terminal contents. Traffic-light buttons stay accessible via menu-bar commands.")
            }

            Section {
                LabeledContent {
                    Stepper(value: $store.windowWidth, in: 0...500, step: 10) {
                        Text(store.windowWidth == 0 ? "Auto" : "\(store.windowWidth) cols")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel("Initial width",
                             modified: store.isModified(\.windowWidth, default: store.defaults.windowWidth),
                             docKey: "window-width")
                }

                LabeledContent {
                    Stepper(value: $store.windowHeight, in: 0...200, step: 5) {
                        Text(store.windowHeight == 0 ? "Auto" : "\(store.windowHeight) rows")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel("Initial height",
                             modified: store.isModified(\.windowHeight, default: store.defaults.windowHeight),
                             docKey: "window-height")
                }
            } header: {
                Text("Initial Size")
            } footer: {
                Text("0 = let the OS decide. Values are in terminal cells (columns × rows), not pixels.")
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

                LabeledContent {
                    Picker("", selection: $store.windowPaddingColor) {
                        ForEach(WindowPaddingColor.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Padding color",
                             modified: store.isModified(\.windowPaddingColor, default: store.defaults.windowPaddingColor),
                             docKey: "window-padding-color")
                }
            } header: {
                Text("Padding")
            } footer: {
                Text("Balancing pads each terminal row evenly when the cell size doesn't divide the window cleanly. **Extend** fills padding with the nearest grid cell's background — useful when a theme paints the prompt's gutter.")
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.macosNonNativeFullscreen) {
                        ForEach(MacosNonNativeFullscreen.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
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

                LabeledContent {
                    Picker("", selection: $store.windowNewTabPosition) {
                        ForEach(WindowNewTabPosition.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("New tab position",
                             modified: store.isModified(\.windowNewTabPosition, default: store.defaults.windowNewTabPosition),
                             docKey: "window-new-tab-position")
                }

                LabeledContent {
                    Picker("", selection: $store.resizeOverlay) {
                        ForEach(ResizeOverlay.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Resize overlay",
                             modified: store.isModified(\.resizeOverlay, default: store.defaults.resizeOverlay),
                             docKey: "resize-overlay")
                }
            } header: {
                Text("Behavior")
            } footer: {
                Text("Non-native fullscreen avoids the macOS animation but loses Spaces integration. Padded-notch keeps the window away from notched displays.")
            }
        }
        .formStyle(.grouped)
        .paneToolbar(title: "Window",
                     subtitle: "Title bar, padding, window behavior.")
    }
}

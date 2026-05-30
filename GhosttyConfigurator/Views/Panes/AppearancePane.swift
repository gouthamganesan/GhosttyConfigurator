import SwiftUI

struct AppearancePane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                if store.themePair.isPair {
                    matchAppearanceToggle(isOn: true)
                    NavigationLink(value: ThemeBrowserMode.lightPair) {
                        LabeledContent {
                            Text(store.themePair.light ?? "—")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sun.max").foregroundStyle(.secondary)
                                Text("Light theme")
                            }
                        }
                    }
                    NavigationLink(value: ThemeBrowserMode.darkPair) {
                        LabeledContent {
                            Text(store.themePair.dark ?? "—")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "moon").foregroundStyle(.secondary)
                                Text("Dark theme")
                            }
                        }
                    }
                } else {
                    NavigationLink(value: ThemeBrowserMode.single) {
                        LabeledContent {
                            Text(store.themePair.single ?? "—")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } label: {
                            HStack(spacing: 6) {
                                Text("Theme")
                                RowAffix(
                                    modState: (store.themePair.single ?? "") != store.defaults
                                        .theme ? .modified : .unchanged,
                                    docKey: "theme"
                                )
                            }
                        }
                    }
                    matchAppearanceToggle(isOn: false)
                }
            } header: {
                Text("Theme")
            } footer: {
                Text(
                    "Themes ship with Ghostty (~460 included) and can also live in `~/.config/ghostty/themes/`. The system-appearance pair writes `theme = light:X,dark:Y` and tracks your macOS appearance."
                )
            }

            Section {
                LabeledContent {
                    SystemSettingsSlider(
                        value: $store.backgroundOpacity,
                        range: 0 ... 1,
                        leadingLabel: "Transparent",
                        trailingLabel: "Opaque"
                    )
                    .frame(width: 240)
                } label: {
                    rowLabel(
                        "Background opacity",
                        modified: store.isModified(\.backgroundOpacity, default: store.defaults.backgroundOpacity),
                        docKey: "background-opacity"
                    )
                }

                LabeledContent {
                    Picker("", selection: $store.backgroundBlur) {
                        ForEach(BlurLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Background blur",
                        modified: store.isModified(\.backgroundBlur, default: store.defaults.backgroundBlur),
                        docKey: "background-blur"
                    )
                }
            } header: {
                Text("Window")
            } footer: {
                Text(
                    "Background blur and opacity apply behind the terminal contents; they don't affect text color. Opacity changes require a full Ghostty restart on macOS."
                )
            }

            Section {
                LabeledContent {
                    ColorPicker("", selection: $store.backgroundColor, supportsOpacity: false)
                        .labelsHidden()
                } label: {
                    rowLabel(
                        "Background",
                        modified: store.isBackgroundColorModified,
                        docKey: "background"
                    )
                }

                LabeledContent {
                    ColorPicker("", selection: $store.foregroundColor, supportsOpacity: false)
                        .labelsHidden()
                } label: {
                    rowLabel(
                        "Foreground",
                        modified: store.isForegroundColorModified,
                        docKey: "foreground"
                    )
                }

                autoColorRow(
                    title: "Cursor color",
                    docKey: "cursor-color",
                    isAuto: $store.isCursorColorAuto,
                    color: $store.cursorColor
                )

                autoColorRow(
                    title: "Selection background",
                    docKey: "selection-background",
                    isAuto: $store.isSelectionBackgroundAuto,
                    color: $store.selectionBackgroundColor
                )

                autoColorRow(
                    title: "Selection foreground",
                    docKey: "selection-foreground",
                    isAuto: $store.isSelectionForegroundAuto,
                    color: $store.selectionForegroundColor
                )

                LabeledContent {
                    HStack(spacing: 8) {
                        Picker("", selection: $store.boldColorMode) {
                            ForEach(BoldColorMode.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                        if store.boldColorMode == .custom {
                            ColorPicker("", selection: $store.boldColorCustom, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                } label: {
                    rowLabel(
                        "Bold color",
                        modified: store.boldColorMode != store.defaults.boldColorMode,
                        docKey: "bold-color"
                    )
                }

                LabeledContent {
                    SystemSettingsSlider(
                        value: $store.minimumContrast,
                        range: 1.0 ... 21.0,
                        leadingLabel: "1.0",
                        trailingLabel: "21.0"
                    )
                    .frame(width: 240)
                } label: {
                    rowLabel(
                        "Minimum contrast",
                        modified: store.isModified(\.minimumContrast, default: store.defaults.minimumContrast),
                        docKey: "minimum-contrast"
                    )
                }
            } header: {
                Text("Colors")
            } footer: {
                Text(
                    "Colors override the active theme. Choose **Auto** to follow the theme. Minimum contrast forces a foreground/background contrast ratio (1.0 = no enforcement, 21.0 = maximum)."
                )
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "Appearance",
            subtitle: "Colors, themes, and visual feel."
        )
        .navigationDestination(for: ThemeBrowserMode.self) { mode in
            ThemeBrowserView(mode: mode)
        }
    }

    // MARK: - Color rows

    /// Row with an "Auto" toggle that controls whether the key is present.
    /// When Auto is on, the ColorPicker is hidden; flipping Auto off seeds
    /// the key with a fallback color so the picker has something to display.
    private func autoColorRow(
        title: String,
        docKey: String,
        isAuto: Binding<Bool>,
        color: Binding<Color>
    ) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                Toggle("Auto", isOn: isAuto)
                    .toggleStyle(.checkbox)
                if !isAuto.wrappedValue {
                    ColorPicker("", selection: color, supportsOpacity: false)
                        .labelsHidden()
                }
            }
        } label: {
            rowLabel(title, modified: !isAuto.wrappedValue, docKey: docKey)
        }
    }

    // MARK: - Pair toggle

    private func matchAppearanceToggle(isOn: Bool) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { enabled in
                if enabled {
                    // Promote single value into a pair (use it for both halves to start).
                    let current = store.themePair.single ?? store.defaults.theme
                    store.setThemePair(light: current, dark: current)
                } else {
                    // Collapse pair to single — prefer the current macOS appearance side.
                    let isDarkMode = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    let value = isDarkMode
                        ? (store.themePair.dark ?? store.themePair.light ?? store.defaults.theme)
                        : (store.themePair.light ?? store.themePair.dark ?? store.defaults.theme)
                    store.setThemeSingle(value)
                }
            }
        )) {
            HStack(spacing: 6) {
                Text("Match system appearance")
                RowAffix(
                    modState: store.themePair.isPair ? .modified : .unchanged,
                    docKey: "theme (light:dark pair)"
                )
            }
        }
    }
}

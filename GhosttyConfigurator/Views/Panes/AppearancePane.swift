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
                                    modState: (store.themePair.single ?? "") != store.defaults.theme ? .modified : .unchanged,
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
                Text("Themes ship with Ghostty (~460 included) and can also live in `~/.config/ghostty/themes/`. The system-appearance pair writes `theme = light:X,dark:Y` and tracks your macOS appearance.")
            }

            Section {
                LabeledContent {
                    SystemSettingsSlider(
                        value: $store.backgroundOpacity,
                        range: 0...1,
                        leadingLabel: "Transparent",
                        trailingLabel: "Opaque"
                    )
                    .frame(width: 240)
                } label: {
                    rowLabel("Background opacity",
                             modified: store.isModified(\.backgroundOpacity, default: store.defaults.backgroundOpacity),
                             docKey: "background-opacity")
                }

                LabeledContent {
                    Picker("", selection: $store.backgroundBlur) {
                        ForEach(BlurLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Background blur",
                             modified: store.isModified(\.backgroundBlur, default: store.defaults.backgroundBlur),
                             docKey: "background-blur")
                }
            } header: {
                Text("Window")
            } footer: {
                Text("Background blur and opacity apply behind the terminal contents; they don't affect text color. Opacity changes require a full Ghostty restart on macOS.")
            }
        }
        .formStyle(.grouped)
        .paneToolbar(title: "Appearance",
                     subtitle: "Colors, themes, and visual feel.")
        .navigationDestination(for: ThemeBrowserMode.self) { mode in
            ThemeBrowserView(mode: mode)
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

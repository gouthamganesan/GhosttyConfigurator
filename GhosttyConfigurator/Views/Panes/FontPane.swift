import SwiftUI

struct FontPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                LabeledContent {
                    HStack(spacing: 6) {
                        Text(store.fontFamily)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        FontPickerButton(
                            currentFamily: store.fontFamily,
                            currentSize: store.fontSize
                        ) { newFamily, newSize in
                            store.fontFamily = newFamily
                            // The font panel always returns a size — apply it
                            // unless it matches the current value (no-op write).
                            if newSize != store.fontSize {
                                store.fontSize = newSize
                            }
                        }
                    }
                } label: {
                    rowLabel("Family",
                             modified: store.isModified(\.fontFamily, default: store.defaults.fontFamily),
                             docKey: "font-family")
                }
            } header: {
                Text("Family")
            } footer: {
                Text("Ghostty supports a fallback chain — repeat `font-family =` lines to add fallbacks. The Choose… button opens macOS's font panel; flip the panel's filter to \"Fixed Width\" to narrow it to terminal-friendly fonts.")
            }

            Section {
                LabeledContent {
                    Stepper(value: $store.fontSize, in: 6...72, step: 0.5) {
                        Text(formattedFontSize)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel("Size",
                             modified: store.isModified(\.fontSize, default: store.defaults.fontSize),
                             docKey: "font-size")
                }
            } header: {
                Text("Size")
            }

            Section {
                Toggle(isOn: $store.fontLigatures) {
                    rowLabel("Standard ligatures",
                             modified: store.fontLigatures != store.defaults.fontLigatures,
                             docKey: "font-feature (+/-liga)")
                }

                Toggle(isOn: $store.fontContextualAlternates) {
                    rowLabel("Contextual alternates",
                             modified: store.fontContextualAlternates != store.defaults.fontContextualAlternates,
                             docKey: "font-feature (+/-calt)")
                }

                Toggle(isOn: $store.fontThicken) {
                    rowLabel("Thicken strokes",
                             modified: store.isModified(\.fontThicken, default: store.defaults.fontThicken),
                             docKey: "font-thicken")
                }
            } header: {
                Text("Features")
            } footer: {
                Text("Standard ligatures (`liga`) and contextual alternates (`calt`) are OpenType features. Thicken adds a subtle stroke weight — useful on non-Retina displays.")
            }
        }
        .formStyle(.grouped)
        .paneToolbar(symbol: "textformat",
                     title: "Font",
                     subtitle: "Family, size, OpenType features.",
                     tint: .indigo)
    }

    private var formattedFontSize: String {
        if store.fontSize == store.fontSize.rounded() {
            return "\(Int(store.fontSize)) pt"
        }
        return String(format: "%.1f pt", store.fontSize)
    }
}

import SwiftUI

struct FontPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                familyRow(
                    title: "Regular",
                    family: store.fontFamily,
                    docKey: "font-family",
                    isPrimary: true
                ) { picked in
                    store.fontFamily = picked
                }
                familyRow(
                    title: "Bold",
                    family: store.fontFamilyBold,
                    docKey: "font-family-bold",
                    isPrimary: false
                ) { picked in
                    store.fontFamilyBold = picked
                }
                familyRow(
                    title: "Italic",
                    family: store.fontFamilyItalic,
                    docKey: "font-family-italic",
                    isPrimary: false
                ) { picked in
                    store.fontFamilyItalic = picked
                }
                familyRow(
                    title: "Bold italic",
                    family: store.fontFamilyBoldItalic,
                    docKey: "font-family-bold-italic",
                    isPrimary: false
                ) { picked in
                    store.fontFamilyBoldItalic = picked
                }
            } header: {
                Text("Family")
            } footer: {
                Text(
                    "Set Bold / Italic / Bold-italic to use different faces for each weight. Leave them empty to use the Regular family for all styles."
                )
            }

            Section {
                LabeledContent {
                    Stepper(value: $store.fontSize, in: 6 ... 72, step: 0.5) {
                        Text(formattedFontSize)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    rowLabel(
                        "Size",
                        modified: store.isModified(\.fontSize, default: store.defaults.fontSize),
                        docKey: "font-size"
                    )
                }

                Toggle(isOn: $store.fontSyntheticStyle) {
                    rowLabel(
                        "Synthesize missing styles",
                        modified: !store.fontSyntheticStyle,
                        docKey: "font-synthetic-style"
                    )
                }

                Toggle(isOn: $store.fontThicken) {
                    rowLabel(
                        "Thicken strokes",
                        modified: store.isModified(\.fontThicken, default: store.defaults.fontThicken),
                        docKey: "font-thicken"
                    )
                }

                if store.fontThicken {
                    LabeledContent {
                        SystemSettingsSlider(
                            value: Binding(
                                get: { Double(store.fontThickenStrength) },
                                set: { store.fontThickenStrength = Int($0.rounded()) }
                            ),
                            range: 0 ... 255,
                            leadingLabel: "0",
                            trailingLabel: "255"
                        )
                        .frame(width: 240)
                    } label: {
                        rowLabel(
                            "Thicken strength",
                            modified: store.isModified(
                                \.fontThickenStrength,
                                default: store.defaults.fontThickenStrength
                            ),
                            docKey: "font-thicken-strength"
                        )
                    }
                }
            } header: {
                Text("Size & Weight")
            } footer: {
                Text(
                    "**Synthesize missing styles** lets Ghostty fake bold/italic glyphs when the font lacks them. **Thicken** adds stroke weight (useful on non-Retina). Strength 0 = lightest, 255 = heaviest."
                )
            }

            Section {
                Toggle(isOn: $store.fontLigatures) {
                    rowLabel(
                        "Standard ligatures",
                        modified: store.fontLigatures != store.defaults.fontLigatures,
                        docKey: "font-feature (+/-liga)"
                    )
                }

                Toggle(isOn: $store.fontContextualAlternates) {
                    rowLabel(
                        "Contextual alternates",
                        modified: store.fontContextualAlternates != store.defaults.fontContextualAlternates,
                        docKey: "font-feature (+/-calt)"
                    )
                }

                Toggle(isOn: $store.fontDiscretionaryLigatures) {
                    rowLabel(
                        "Discretionary ligatures",
                        modified: store.fontDiscretionaryLigatures != store.defaults.fontDiscretionaryLigatures,
                        docKey: "font-feature (+/-dlig)"
                    )
                }

                Toggle(isOn: $store.fontHistoricalLigatures) {
                    rowLabel(
                        "Historical ligatures",
                        modified: store.fontHistoricalLigatures != store.defaults.fontHistoricalLigatures,
                        docKey: "font-feature (+/-hlig)"
                    )
                }

                LabeledContent {
                    Picker("", selection: $store.fontNumerals) {
                        ForEach(FontNumerals.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Numerals",
                        modified: store.fontNumerals != store.defaults.fontNumerals,
                        docKey: "font-feature (tnum/pnum/onum/lnum)"
                    )
                }
            } header: {
                Text("OpenType Features")
            } footer: {
                Text(
                    "Liga/calt are widely supported. Dlig (e.g. `fi`→ﬁ rare ligatures) and hlig (`ct`→ﬅ historical forms) need a font that ships those alternates. Numerals: tabular = monospaced digits; old-style = mixed-ascender digits (1234567890)."
                )
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "Font",
            subtitle: "Family, size, OpenType features."
        )
    }

    // MARK: - Rows

    private func familyRow(
        title: String,
        family: String,
        docKey: String,
        isPrimary: Bool,
        onPick: @escaping (String) -> Void
    ) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                Text(displayLabel(for: family, isPrimary: isPrimary))
                    .font(.system(size: 13, design: family.isEmpty && !isPrimary ? .default : .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
                FontPickerButton(
                    currentFamily: family.isEmpty ? store.fontFamily : family,
                    currentSize: store.fontSize
                ) { picked, size in
                    onPick(picked)
                    if isPrimary, size != store.fontSize {
                        store.fontSize = size
                    }
                }
                if !isPrimary, !family.isEmpty {
                    Button {
                        onPick("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .help("Use the Regular family")
                }
            }
        } label: {
            rowLabel(
                title,
                modified: isPrimary
                    ? family != store.defaults.fontFamily
                    : !family.isEmpty,
                docKey: docKey
            )
        }
    }

    private func displayLabel(for family: String, isPrimary: Bool) -> String {
        if family.isEmpty {
            return isPrimary ? "—" : "Same as Regular"
        }
        return family
    }

    private var formattedFontSize: String {
        if store.fontSize == store.fontSize.rounded() {
            return "\(Int(store.fontSize)) pt"
        }
        return String(format: "%.1f pt", store.fontSize)
    }
}

import SwiftUI

struct CursorPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $store.cursorStyle) {
                        ForEach(CursorStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Style",
                             modified: store.isModified(\.cursorStyle, default: store.defaults.cursorStyle),
                             docKey: "cursor-style")
                }

                LabeledContent {
                    Picker("", selection: $store.cursorStyleBlink) {
                        ForEach(CursorStyleBlink.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel("Blink",
                             modified: store.isModified(\.cursorStyleBlink, default: store.defaults.cursorStyleBlink),
                             docKey: "cursor-style-blink")
                }

                LabeledContent {
                    SystemSettingsSlider(
                        value: $store.cursorOpacity,
                        range: 0...1,
                        leadingLabel: "Transparent",
                        trailingLabel: "Opaque"
                    )
                    .frame(width: 240)
                } label: {
                    rowLabel("Opacity",
                             modified: store.isModified(\.cursorOpacity, default: store.defaults.cursorOpacity),
                             docKey: "cursor-opacity")
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        Toggle("Auto", isOn: $store.isCursorColorAuto)
                            .toggleStyle(.checkbox)
                        if !store.isCursorColorAuto {
                            ColorPicker("", selection: $store.cursorColor, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                } label: {
                    rowLabel("Color",
                             modified: !store.isCursorColorAuto,
                             docKey: "cursor-color")
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        Picker("", selection: $store.cursorTextMode) {
                            ForEach(CursorTextMode.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                        if store.cursorTextMode == .custom {
                            ColorPicker("", selection: $store.cursorTextCustom, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                } label: {
                    rowLabel("Text color",
                             modified: store.cursorTextMode != store.defaults.cursorTextMode,
                             docKey: "cursor-text")
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("**Blink** \"Default\" lets programs control blinking via DEC Mode 12; \"Always\"/\"Never\" lock the cursor and ignore that mode. **Text color** draws the text *under* the cursor — set it to *cell foreground* for inverted-cursor look.")
            }

            Section {
                Toggle(isOn: $store.cursorClickToMove) {
                    rowLabel("Click to move cursor",
                             modified: store.isModified(\.cursorClickToMove, default: store.defaults.cursorClickToMove),
                             docKey: "cursor-click-to-move")
                }

                Toggle(isOn: $store.mouseHideWhileTyping) {
                    rowLabel("Hide mouse while typing",
                             modified: store.isModified(\.mouseHideWhileTyping, default: store.defaults.mouseHideWhileTyping),
                             docKey: "mouse-hide-while-typing")
                }
            } header: {
                Text("Behavior")
            } footer: {
                Text("Click-to-move requires shell integration to know where the prompt is.")
            }
        }
        .formStyle(.grouped)
        .paneToolbar(title: "Cursor",
                     subtitle: "Shape, blink, click behavior.")
    }
}

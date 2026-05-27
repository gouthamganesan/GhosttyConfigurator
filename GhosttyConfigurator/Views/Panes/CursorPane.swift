import SwiftUI

struct CursorPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                HeroCard(
                    symbol: "cursorarrow.rays",
                    title: "Cursor",
                    description: "Shape, blink, and click behavior for the terminal cursor.",
                    iconGradient: [.teal, .cyan]
                )
            }

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

                Toggle(isOn: $store.cursorStyleBlink) {
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
            } header: {
                Text("Appearance")
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
    }
}

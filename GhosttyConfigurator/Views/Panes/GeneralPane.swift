import SwiftUI

struct GeneralPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $store.autoUpdate) {
                        ForEach(AutoUpdateMode.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Automatic updates",
                        modified: store.isModified(\.autoUpdate, default: store.defaults.autoUpdate),
                        docKey: "auto-update"
                    )
                }

                LabeledContent {
                    Picker("", selection: $store.autoUpdateChannel) {
                        ForEach(AutoUpdateChannel.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                    .disabled(store.autoUpdate == .off)
                } label: {
                    rowLabel(
                        "Update channel",
                        modified: store.isModified(\.autoUpdateChannel, default: store.defaults.autoUpdateChannel),
                        docKey: "auto-update-channel"
                    )
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Tip-channel builds may include unreleased features but can be unstable.")
            }

            Section {
                LabeledContent {
                    Picker("", selection: $store.confirmCloseSurface) {
                        ForEach(ConfirmCloseSurface.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Confirm before closing",
                        modified: store.isModified(
                            \.confirmCloseSurface,
                            default: store.defaults.confirmCloseSurface
                        ),
                        docKey: "confirm-close-surface"
                    )
                }

                Toggle(isOn: $store.quitAfterLastWindowClosed) {
                    rowLabel(
                        "Quit when last window closes",
                        modified: store.isModified(
                            \.quitAfterLastWindowClosed,
                            default: store.defaults.quitAfterLastWindowClosed
                        ),
                        docKey: "quit-after-last-window-closed"
                    )
                }
            } header: {
                Text("Closing")
            }

            Section {
                Toggle(isOn: $store.desktopNotifications) {
                    rowLabel(
                        "Desktop notifications",
                        modified: store.isModified(
                            \.desktopNotifications,
                            default: store.defaults.desktopNotifications
                        ),
                        docKey: "desktop-notifications"
                    )
                }

                LabeledContent {
                    SystemSettingsSlider(
                        value: $store.bellAudioVolume,
                        range: 0 ... 1,
                        leadingLabel: "Silent",
                        trailingLabel: "Loud"
                    )
                    .frame(width: 240)
                } label: {
                    rowLabel(
                        "Bell volume",
                        modified: store.isModified(\.bellAudioVolume, default: store.defaults.bellAudioVolume),
                        docKey: "bell-audio-volume"
                    )
                }
            } header: {
                Text("Notifications")
            }

            Section {
                Toggle(isOn: $store.macosAutoSecureInput) {
                    rowLabel(
                        "Enable secure input at password prompts",
                        modified: store.isModified(
                            \.macosAutoSecureInput,
                            default: store.defaults.macosAutoSecureInput
                        ),
                        docKey: "macos-auto-secure-input"
                    )
                }

                Toggle(isOn: $store.macosSecureInputIndication) {
                    rowLabel(
                        "Show secure-input indicator",
                        modified: store.isModified(
                            \.macosSecureInputIndication,
                            default: store.defaults.macosSecureInputIndication
                        ),
                        docKey: "macos-secure-input-indication"
                    )
                }
            } header: {
                Text("Security")
            } footer: {
                Text(
                    "Secure input blocks other apps (and macOS itself) from reading keystrokes typed at the terminal. Requires shell integration to detect password prompts."
                )
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "General",
            subtitle: "Updates, lifecycle, notifications."
        )
    }
}

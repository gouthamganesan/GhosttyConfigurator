import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GeneralPane: View {
    @Environment(ConfigStore.self) private var store

    @State private var checkUpdatesError: String?
    @State private var showCheckUpdatesError: Bool = false

    var body: some View {
        @Bindable var store = store

        Form {
            startupSection(store: store)
            updatesSection(store: store)
            closingSection(store: store)
            notificationsSection(store: store)
            bellSection(store: store)
            macOSSection(store: store)
            dockIconSection(store: store)
            securitySection(store: store)
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "General",
            subtitle: "Startup, updates, lifecycle, dock icon, security."
        )
        .alert(
            "Couldn't trigger update check",
            isPresented: $showCheckUpdatesError,
            presenting: checkUpdatesError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    // MARK: - Sections

    private func startupSection(store: ConfigStore) -> some View {
        Section {
            LabeledContent {
                Button("Open Login Items…") {
                    openLoginItemsSettings()
                }
            } label: {
                rowLabel(
                    "Launch Ghostty at login",
                    modified: false,
                    docKey: nil
                )
            }
        } header: {
            Text("Startup")
        } footer: {
            Text(
                "Managed by macOS — drag Ghostty.app into the Login Items list, or use the Login Items pane of System Settings."
            )
        }
    }

    private func updatesSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
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

            LabeledContent {
                Button("Check now") {
                    Task { await triggerUpdateCheck() }
                }
                .disabled(!GhosttyReloader.isGhosttyRunning && ConfigPaths.ghosttyAppURL() == nil)
            } label: {
                rowLabel(
                    "Check for updates now",
                    modified: false,
                    docKey: nil
                )
            }
        } header: {
            Text("Updates")
        } footer: {
            Text("Tip-channel builds may include unreleased features but can be unstable.")
        }
    }

    private func closingSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
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

            LabeledContent {
                TextField("e.g. 30s, 5m, 1h", text: $store.quitDelay)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .disabled(!store.quitAfterLastWindowClosed)
            } label: {
                rowLabel(
                    "Quit delay",
                    modified: !store.quitDelay.isEmpty,
                    docKey: "quit-after-last-window-closed-delay"
                )
            }
        } header: {
            Text("Closing")
        } footer: {
            Text(
                "Quit delay only applies if the toggle above is on. Format: number + unit (`s`, `m`, `h`, `d`); units can be combined (`1h30m`). Minimum 1 second."
            )
        }
    }

    private func notificationsSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
            Toggle(isOn: $store.desktopNotifications) {
                rowLabel(
                    "Allow desktop notifications from programs",
                    modified: store.isModified(
                        \.desktopNotifications,
                        default: store.defaults.desktopNotifications
                    ),
                    docKey: "desktop-notifications"
                )
            }

            LabeledContent {
                Picker("", selection: $store.notifyOnCommandFinish) {
                    ForEach(NotifyOnCommandFinish.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            } label: {
                rowLabel(
                    "Notify when a command finishes",
                    modified: store.isModified(
                        \.notifyOnCommandFinish,
                        default: store.defaults.notifyOnCommandFinish
                    ),
                    docKey: "notify-on-command-finish"
                )
            }

            if store.notifyOnCommandFinish != .never {
                LabeledContent {
                    TextField("e.g. 5s, 30s, 1m", text: $store.notifyOnCommandFinishAfter)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                } label: {
                    rowLabel(
                        "Only after running for",
                        modified: !store.notifyOnCommandFinishAfter.isEmpty,
                        docKey: "notify-on-command-finish-after"
                    )
                }

                LabeledContent {
                    HStack(spacing: 14) {
                        Toggle("Bell", isOn: $store.notifyActionBell).toggleStyle(.checkbox)
                        Toggle("Notification", isOn: $store.notifyActionNotify).toggleStyle(.checkbox)
                    }
                } label: {
                    rowLabel(
                        "Notification style",
                        modified: store.isModified(\.notifyActionBell, default: store.defaults.notifyActionBell)
                            || store.isModified(\.notifyActionNotify, default: store.defaults.notifyActionNotify),
                        docKey: "notify-on-command-finish-action"
                    )
                }
            }

            LabeledContent {
                HStack(spacing: 14) {
                    Toggle("Clipboard copied", isOn: $store.appNotificationClipboardCopy).toggleStyle(.checkbox)
                    Toggle("Config reloaded", isOn: $store.appNotificationConfigReload).toggleStyle(.checkbox)
                }
            } label: {
                rowLabel(
                    "In-app toasts",
                    modified: store.isModified(
                        \.appNotificationClipboardCopy,
                        default: store.defaults.appNotificationClipboardCopy
                    )
                        || store.isModified(
                            \.appNotificationConfigReload,
                            default: store.defaults.appNotificationConfigReload
                        ),
                    docKey: "app-notifications"
                )
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(
                "Command-finished notifications need shell integration (or OSC 133) so Ghostty knows when a command actually wraps."
            )
        }
    }

    private func bellSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
            LabeledContent {
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("System alert sound", isOn: $store.bellFeatureSystem).toggleStyle(.checkbox)
                    Toggle("Custom audio file", isOn: $store.bellFeatureAudio).toggleStyle(.checkbox)
                    Toggle("Bounce dock icon", isOn: $store.bellFeatureAttention).toggleStyle(.checkbox)
                    Toggle("🔔 in window title", isOn: $store.bellFeatureTitle).toggleStyle(.checkbox)
                    Toggle("Highlight surface border", isOn: $store.bellFeatureBorder).toggleStyle(.checkbox)
                }
            } label: {
                rowLabel(
                    "Bell features",
                    modified: store.isModified(\.bellFeatureSystem, default: store.defaults.bellFeatureSystem)
                        || store.isModified(\.bellFeatureAudio, default: store.defaults.bellFeatureAudio)
                        || store.isModified(\.bellFeatureAttention, default: store.defaults.bellFeatureAttention)
                        || store.isModified(\.bellFeatureTitle, default: store.defaults.bellFeatureTitle)
                        || store.isModified(\.bellFeatureBorder, default: store.defaults.bellFeatureBorder),
                    docKey: "bell-features"
                )
            }

            if store.bellFeatureAudio {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(store.bellAudioPath.isEmpty ? "Not set" : (store.bellAudioPath as NSString)
                            .lastPathComponent)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200, alignment: .trailing)
                        Button("Choose…") { pickBellAudio() }
                        if !store.bellAudioPath.isEmpty {
                            Button {
                                store.bellAudioPath = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .help("Clear the audio path")
                            .accessibilityLabel("Clear audio path")
                        }
                    }
                } label: {
                    rowLabel(
                        "Audio file",
                        modified: !store.bellAudioPath.isEmpty,
                        docKey: "bell-audio-path"
                    )
                }
            }

            LabeledContent {
                SystemSettingsSlider(
                    value: $store.bellAudioVolume,
                    range: 0 ... 1,
                    leadingLabel: "Silent",
                    trailingLabel: "Loud"
                )
                .frame(width: 240)
                .disabled(!store.bellFeatureAudio)
            } label: {
                rowLabel(
                    "Audio volume",
                    modified: store.isModified(\.bellAudioVolume, default: store.defaults.bellAudioVolume),
                    docKey: "bell-audio-volume"
                )
            }
        } header: {
            Text("Bell")
        } footer: {
            Text(
                "**Attention** bounces the dock icon when Ghostty is unfocused. **Title** marks the surface with 🔔 until you re-focus. **Audio** plays the chosen file if one is set."
            )
        }
    }

    private func macOSSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
            Toggle(isOn: $store.macosApplescript) {
                rowLabel(
                    "AppleScript integration",
                    modified: store.isModified(\.macosApplescript, default: store.defaults.macosApplescript),
                    docKey: "macos-applescript"
                )
            }

            LabeledContent {
                Picker("", selection: $store.macosDockDropBehavior) {
                    ForEach(MacosDockDropBehavior.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            } label: {
                rowLabel(
                    "Dock drop behaviour",
                    modified: store.isModified(
                        \.macosDockDropBehavior,
                        default: store.defaults.macosDockDropBehavior
                    ),
                    docKey: "macos-dock-drop-behavior"
                )
            }
        } header: {
            Text("macOS")
        } footer: {
            Text(
                "Drop behaviour controls whether dragging a file/folder onto Ghostty's dock icon creates a tab or a window."
            )
        }
    }

    private func dockIconSection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
            LabeledContent {
                Picker("", selection: $store.macosIcon) {
                    ForEach(MacosIcon.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            } label: {
                rowLabel(
                    "Dock icon",
                    modified: store.isModified(\.macosIcon, default: store.defaults.macosIcon),
                    docKey: "macos-icon"
                )
            }

            if store.macosIcon == .customStyle {
                LabeledContent {
                    Picker("", selection: $store.macosIconFrame) {
                        ForEach(MacosIconFrame.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Frame",
                        modified: store.isModified(\.macosIconFrame, default: store.defaults.macosIconFrame),
                        docKey: "macos-icon-frame"
                    )
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        ColorPicker("", selection: $store.macosIconGhostColor, supportsOpacity: false)
                            .labelsHidden()
                        Toggle("Auto", isOn: $store.isMacosIconGhostColorAuto)
                            .toggleStyle(.checkbox)
                    }
                } label: {
                    rowLabel(
                        "Ghost colour",
                        modified: !store.isMacosIconGhostColorAuto,
                        docKey: "macos-icon-ghost-color"
                    )
                }

                LabeledContent {
                    TextField("e.g. #2e3192, #ee2a7b", text: $store.macosIconScreenColor)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                } label: {
                    rowLabel(
                        "Screen gradient",
                        modified: !store.macosIconScreenColor.isEmpty,
                        docKey: "macos-icon-screen-color"
                    )
                }
            }
        } header: {
            Text("Dock icon")
        } footer: {
            if store.macosIcon == .customStyle {
                Text(
                    "Screen gradient takes up to 64 comma-separated colours. The first is the bottom, the last is the top. Hex (`#RRGGBB`) or X11 names accepted."
                )
            } else if store.macosIcon == .custom {
                Text(
                    "`custom` requires setting `macos-custom-icon` in the config file to an image path — not exposed in the UI yet."
                )
            } else {
                Text("Affects the dock and app switcher icon only. Finder shows the bundle's signed icon.")
            }
        }
    }

    private func securitySection(store: ConfigStore) -> some View {
        @Bindable var store = store
        return Section {
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

    // MARK: - Actions

    private func openLoginItemsSettings() {
        // macOS 13+ exposes the Login Items pane via this URL scheme.
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func triggerUpdateCheck() async {
        do {
            try await GhosttyReloader.checkForUpdates()
        } catch {
            checkUpdatesError = String(describing: error)
            showCheckUpdatesError = true
        }
    }

    private func pickBellAudio() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        // Ghostty accepts any system-decodable audio file; restrict to the
        // common ones it documents (wav, mp3, aiff) for user clarity.
        panel.allowedContentTypes = [.audio, .wav, .mp3, .aiff].compactMap { $0 }
        panel.message = "Choose an audio file for the bell"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.bellAudioPath = url.path
    }
}

import Foundation

/// A6 — Notifications + Bell accessors split out so `ConfigStore.swift` stays
/// under the SwiftLint file-length limit. Pure forwarding to the same
/// scalar/enum/comma-flag helpers the main store uses.
@MainActor
extension ConfigStore {
    // MARK: - notify-on-command-finish*

    var notifyOnCommandFinish: NotifyOnCommandFinish {
        get {
            file.enumValue(
                NotifyOnCommandFinish.self,
                for: "notify-on-command-finish",
                default: defaults.notifyOnCommandFinish
            )
        }
        set { setEnum("notify-on-command-finish", newValue, label: "Change Notify-on-Finish") }
    }

    var notifyOnCommandFinishAfter: String {
        get { file.scalarValue(for: "notify-on-command-finish-after") ?? defaults.notifyOnCommandFinishAfter }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                deleteKey("notify-on-command-finish-after", label: "Clear Notify Delay")
            } else {
                setScalar("notify-on-command-finish-after", value: trimmed, label: "Change Notify Delay")
            }
        }
    }

    var notifyActionBell: Bool {
        get { isCommaFlagEnabled("notify-on-command-finish-action", flag: "bell", default: defaults.notifyActionBell) }
        set { setCommaFlag(
            "notify-on-command-finish-action",
            flag: "bell",
            enabled: newValue,
            label: "Toggle Bell on Command Finish"
        ) }
    }

    var notifyActionNotify: Bool {
        get { isCommaFlagEnabled(
            "notify-on-command-finish-action",
            flag: "notify",
            default: defaults.notifyActionNotify
        ) }
        set { setCommaFlag(
            "notify-on-command-finish-action",
            flag: "notify",
            enabled: newValue,
            label: "Toggle Desktop Notify on Command Finish"
        ) }
    }

    // MARK: - app-notifications

    var appNotificationClipboardCopy: Bool {
        get { isCommaFlagEnabled(
            "app-notifications",
            flag: "clipboard-copy",
            default: defaults.appNotificationClipboardCopy
        ) }
        set { setCommaFlag(
            "app-notifications",
            flag: "clipboard-copy",
            enabled: newValue,
            label: "Toggle Clipboard-Copy Notification"
        ) }
    }

    var appNotificationConfigReload: Bool {
        get { isCommaFlagEnabled(
            "app-notifications",
            flag: "config-reload",
            default: defaults.appNotificationConfigReload
        ) }
        set { setCommaFlag(
            "app-notifications",
            flag: "config-reload",
            enabled: newValue,
            label: "Toggle Config-Reload Notification"
        ) }
    }

    // MARK: - bell-features

    var bellFeatureSystem: Bool {
        get { isCommaFlagEnabled("bell-features", flag: "system", default: defaults.bellFeatureSystem) }
        set { setCommaFlag("bell-features", flag: "system", enabled: newValue, label: "Toggle System Bell") }
    }

    var bellFeatureAudio: Bool {
        get { isCommaFlagEnabled("bell-features", flag: "audio", default: defaults.bellFeatureAudio) }
        set { setCommaFlag("bell-features", flag: "audio", enabled: newValue, label: "Toggle Audio Bell") }
    }

    var bellFeatureAttention: Bool {
        get { isCommaFlagEnabled("bell-features", flag: "attention", default: defaults.bellFeatureAttention) }
        set { setCommaFlag("bell-features", flag: "attention", enabled: newValue, label: "Toggle Attention Bell") }
    }

    var bellFeatureTitle: Bool {
        get { isCommaFlagEnabled("bell-features", flag: "title", default: defaults.bellFeatureTitle) }
        set { setCommaFlag("bell-features", flag: "title", enabled: newValue, label: "Toggle Title Bell") }
    }

    var bellFeatureBorder: Bool {
        get { isCommaFlagEnabled("bell-features", flag: "border", default: defaults.bellFeatureBorder) }
        set { setCommaFlag("bell-features", flag: "border", enabled: newValue, label: "Toggle Border Bell") }
    }

    // MARK: - bell-audio-path

    var bellAudioPath: String {
        get { file.scalarValue(for: "bell-audio-path") ?? defaults.bellAudioPath }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                deleteKey("bell-audio-path", label: "Clear Bell Audio Path")
            } else {
                setScalar("bell-audio-path", value: trimmed, label: "Set Bell Audio Path")
            }
        }
    }
}

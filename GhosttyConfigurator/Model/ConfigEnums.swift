import SwiftUI

// MARK: - Appearance

enum BlurLevel: String, CaseIterable, Identifiable, Hashable, Sendable {
    case off, subtle, medium, strong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:    "Off"
        case .subtle: "Subtle"
        case .medium: "Medium"
        case .strong: "Strong"
        }
    }

    /// Ghostty's `background-blur` accepts `false`, `true`, or a radius int.
    /// We map our four-step UX to representative radii.
    var configValue: String {
        switch self {
        case .off:    "false"
        case .subtle: "10"
        case .medium: "20"
        case .strong: "40"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "false", "0":  self = .off
        case "true":        self = .medium
        default:
            guard let n = Int(rawString) else { return nil }
            switch n {
            case 0:        self = .off
            case 1..<15:   self = .subtle
            case 15..<30:  self = .medium
            default:       self = .strong
            }
        }
    }
}

// MARK: - Cursor

enum CursorStyle: String, CaseIterable, Identifiable, Hashable, Sendable {
    case block, bar, underline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .block:     "Block"
        case .bar:       "Bar"
        case .underline: "Underline"
        }
    }
}

// MARK: - Window

/// `macos-titlebar-style` — controls how the title bar renders on macOS.
enum TitlebarStyle: String, CaseIterable, Identifiable, Hashable, Sendable {
    case native, transparent, tabs, hidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .native:      "Native"
        case .transparent: "Transparent"
        case .tabs:        "Tabs in title bar"
        case .hidden:      "Hidden"
        }
    }
}

/// `macos-window-buttons` — show or hide the traffic-light buttons.
enum MacosWindowButtons: String, CaseIterable, Identifiable, Hashable, Sendable {
    case visible, hidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .visible: "Visible"
        case .hidden:  "Hidden"
        }
    }
}

/// `window-decoration` — controls window chrome rendering.
enum WindowDecoration: String, CaseIterable, Identifiable, Hashable, Sendable {
    case auto, none, server, client

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:   "Automatic"
        case .none:   "None"
        case .server: "Server-side"
        case .client: "Client-side"
        }
    }
}

/// `window-save-state` — restore windows across launches.
enum WindowSaveState: String, CaseIterable, Identifiable, Hashable, Sendable {
    case `default`, always, never

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: "Default"
        case .always:  "Always"
        case .never:   "Never"
        }
    }
}

// MARK: - Clipboard & Mouse

enum ClipboardPermission: String, CaseIterable, Identifiable, Hashable, Sendable {
    case allow, deny, ask

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allow: "Allow"
        case .deny:  "Deny"
        case .ask:   "Always ask"
        }
    }
}

/// `copy-on-select` — Ghostty accepts `true`/`false`/`clipboard`.
enum CopyOnSelect: String, CaseIterable, Identifiable, Hashable, Sendable {
    case off, primary, clipboard

    var id: String { rawValue }

    var configValue: String {
        switch self {
        case .off:       "false"
        case .primary:   "true"
        case .clipboard: "clipboard"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "false":     self = .off
        case "true":      self = .primary
        case "clipboard": self = .clipboard
        default:          return nil
        }
    }

    var label: String {
        switch self {
        case .off:       "Off"
        case .primary:   "Primary selection"
        case .clipboard: "System clipboard"
        }
    }
}

/// `mouse-shift-capture` — controls whether shift-click is captured by apps.
enum MouseShiftCapture: String, CaseIterable, Identifiable, Hashable, Sendable {
    case always, never, falseValue = "false", trueValue = "true"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .always:     "Always"
        case .never:      "Never"
        case .falseValue: "Disabled (terminal apps decide)"
        case .trueValue:  "Enabled (terminal apps decide)"
        }
    }
}

// MARK: - Shell

enum ShellIntegration: String, CaseIterable, Identifiable, Hashable, Sendable {
    case detect, none, bash, zsh, fish, elvish

    var id: String { rawValue }

    /// `shell-integration` uses `detect` (auto-detect from $SHELL), per docs.
    var configValue: String {
        switch self {
        case .detect: "detect"
        case .none:   "none"
        case .bash:   "bash"
        case .zsh:    "zsh"
        case .fish:   "fish"
        case .elvish: "elvish"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "detect", "auto": self = .detect
        case "none", "off":    self = .none
        case "bash":           self = .bash
        case "zsh":            self = .zsh
        case "fish":           self = .fish
        case "elvish":         self = .elvish
        default:               return nil
        }
    }

    var label: String {
        switch self {
        case .detect: "Auto-detect"
        case .none:   "Disabled"
        case .bash:   "Bash"
        case .zsh:    "Zsh"
        case .fish:   "Fish"
        case .elvish: "Elvish"
        }
    }
}

// MARK: - General

enum AutoUpdateMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case off, check, download

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:      "Off"
        case .check:    "Check only"
        case .download: "Download in background"
        }
    }
}

enum AutoUpdateChannel: String, CaseIterable, Identifiable, Hashable, Sendable {
    case stable, tip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stable: "Stable"
        case .tip:    "Tip (pre-release)"
        }
    }
}

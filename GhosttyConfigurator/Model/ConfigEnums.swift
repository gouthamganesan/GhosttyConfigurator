import SwiftUI

// MARK: - Appearance

/// `bold-color` — accepts a hex color, the literal `bright` (use the bright
/// ANSI variant of the foreground color), or omission (no bolding tweak).
/// We split mode from the custom hex so the UI can disclose a ColorPicker
/// only when `.custom` is selected.
enum BoldColorMode: String, CaseIterable, Identifiable, Hashable {
    case none, bright, custom

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .none: "Default"
        case .bright: "Bright variant"
        case .custom: "Custom color"
        }
    }
}

enum BlurLevel: String, CaseIterable, Identifiable, Hashable {
    case off, subtle, medium, strong

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .medium: "Medium"
        case .strong: "Strong"
        }
    }

    /// Ghostty's `background-blur` accepts `false`, `true`, or a radius int.
    /// We map our four-step UX to representative radii.
    var configValue: String {
        switch self {
        case .off: "false"
        case .subtle: "10"
        case .medium: "20"
        case .strong: "40"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "false", "0": self = .off
        case "true": self = .medium
        default:
            guard let n = Int(rawString) else { return nil }
            switch n {
            case 0: self = .off
            case 1 ..< 15: self = .subtle
            case 15 ..< 30: self = .medium
            default: self = .strong
            }
        }
    }
}

// MARK: - Cursor

enum CursorStyle: String, CaseIterable, Identifiable, Hashable {
    case block, bar, underline

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .block: "Block"
        case .bar: "Bar"
        case .underline: "Underline"
        }
    }
}

/// `cursor-style-blink` — tri-state, not Bool. Absence means "respect DEC
/// Mode 12 (programs can override)", which is distinct from explicit `true`
/// / `false` (lock the value, ignore DEC Mode 12).
enum CursorStyleBlink: String, CaseIterable, Identifiable, Hashable {
    case `default`
    case alwaysBlink = "true"
    case neverBlink = "false"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .default: "Default (programs decide)"
        case .alwaysBlink: "Always blink"
        case .neverBlink: "Never blink"
        }
    }
}

/// Numerals figure style. Maps to four mutually-exclusive OpenType features
/// (`+tnum` / `+pnum` / `+onum` / `+lnum`); writing one clears the others.
enum FontNumerals: String, CaseIterable, Identifiable, Hashable {
    case `default`
    case tabular = "tnum"
    case proportional = "pnum"
    case oldStyle = "onum"
    case lining = "lnum"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .default: "Default"
        case .tabular: "Tabular (equal width)"
        case .proportional: "Proportional"
        case .oldStyle: "Old-style"
        case .lining: "Lining"
        }
    }
}

/// `cursor-text` — color of text under the cursor. Four modes mirror
/// `bold-color`: default (key absent), match cell background, match cell
/// foreground, or a literal hex.
enum CursorTextMode: String, CaseIterable, Identifiable, Hashable {
    case `default`
    case cellBackground = "cell-background"
    case cellForeground = "cell-foreground"
    case custom

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .default: "Default"
        case .cellBackground: "Cell background"
        case .cellForeground: "Cell foreground"
        case .custom: "Custom color"
        }
    }
}

// MARK: - Window

/// `macos-titlebar-style` — controls how the title bar renders on macOS.
enum TitlebarStyle: String, CaseIterable, Identifiable, Hashable {
    case native, transparent, tabs, hidden

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .native: "Native"
        case .transparent: "Transparent"
        case .tabs: "Tabs in title bar"
        case .hidden: "Hidden"
        }
    }
}

/// `macos-window-buttons` — show or hide the traffic-light buttons.
enum MacosWindowButtons: String, CaseIterable, Identifiable, Hashable {
    case visible, hidden

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .visible: "Visible"
        case .hidden: "Hidden"
        }
    }
}

/// `window-decoration` — controls window chrome rendering.
enum WindowDecoration: String, CaseIterable, Identifiable, Hashable {
    case auto, none, server, client

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .auto: "Automatic"
        case .none: "None"
        case .server: "Server-side"
        case .client: "Client-side"
        }
    }
}

/// `window-save-state` — restore windows across launches.
enum WindowSaveState: String, CaseIterable, Identifiable, Hashable {
    case `default`, always, never

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .default: "Default"
        case .always: "Always"
        case .never: "Never"
        }
    }
}

/// `macos-non-native-fullscreen` — four states, not Bool. Reads `true`/`false`
/// as the original two, plus `visible-menu` and `padded-notch` variants.
enum MacosNonNativeFullscreen: String, CaseIterable, Identifiable, Hashable {
    case off = "false"
    case on = "true"
    case visibleMenu = "visible-menu"
    case paddedNotch = "padded-notch"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .off: "Native (default)"
        case .on: "Non-native, hide menu bar"
        case .visibleMenu: "Non-native, keep menu bar"
        case .paddedNotch: "Non-native, avoid notch"
        }
    }
}

/// `macos-titlebar-proxy-icon` — show or hide the folder icon in the titlebar.
enum MacosTitlebarProxyIcon: String, CaseIterable, Identifiable, Hashable {
    case visible, hidden

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .visible: "Visible"
        case .hidden: "Hidden"
        }
    }
}

/// `window-padding-color` — how the padding area fills.
enum WindowPaddingColor: String, CaseIterable, Identifiable, Hashable {
    case background
    case extend
    case extendAlways = "extend-always"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .background: "Background"
        case .extend: "Extend nearest cell"
        case .extendAlways: "Always extend"
        }
    }
}

/// `window-new-tab-position` — insertion point for new tabs.
enum WindowNewTabPosition: String, CaseIterable, Identifiable, Hashable {
    case current, end

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .current: "After current tab"
        case .end: "At end of tab list"
        }
    }
}

/// `resize-overlay` — when the resize popup is shown.
enum ResizeOverlay: String, CaseIterable, Identifiable, Hashable {
    case always, never
    case afterFirst = "after-first"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .always: "Always"
        case .never: "Never"
        case .afterFirst: "After first resize"
        }
    }
}

// MARK: - Clipboard & Mouse

enum ClipboardPermission: String, CaseIterable, Identifiable, Hashable {
    case allow, deny, ask

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .allow: "Allow"
        case .deny: "Deny"
        case .ask: "Always ask"
        }
    }
}

/// `copy-on-select` — Ghostty accepts `true`/`false`/`clipboard`.
enum CopyOnSelect: String, CaseIterable, Identifiable, Hashable {
    case off, primary, clipboard

    var id: String {
        rawValue
    }

    var configValue: String {
        switch self {
        case .off: "false"
        case .primary: "true"
        case .clipboard: "clipboard"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "false": self = .off
        case "true": self = .primary
        case "clipboard": self = .clipboard
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .primary: "Primary selection"
        case .clipboard: "System clipboard"
        }
    }
}

/// `mouse-shift-capture` — controls whether shift-click is captured by apps.
enum MouseShiftCapture: String, CaseIterable, Identifiable, Hashable {
    case always, never, falseValue = "false", trueValue = "true"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .always: "Always"
        case .never: "Never"
        case .falseValue: "Disabled (terminal apps decide)"
        case .trueValue: "Enabled (terminal apps decide)"
        }
    }
}

// MARK: - Shell

enum ShellIntegration: String, CaseIterable, Identifiable, Hashable {
    case detect, none, bash, zsh, fish, elvish

    var id: String {
        rawValue
    }

    /// `shell-integration` uses `detect` (auto-detect from $SHELL), per docs.
    var configValue: String {
        switch self {
        case .detect: "detect"
        case .none: "none"
        case .bash: "bash"
        case .zsh: "zsh"
        case .fish: "fish"
        case .elvish: "elvish"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "detect", "auto": self = .detect
        case "none", "off": self = .none
        case "bash": self = .bash
        case "zsh": self = .zsh
        case "fish": self = .fish
        case "elvish": self = .elvish
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .detect: "Auto-detect"
        case .none: "Disabled"
        case .bash: "Bash"
        case .zsh: "Zsh"
        case .fish: "Fish"
        case .elvish: "Elvish"
        }
    }
}

// MARK: - Scrollback

/// `right-click-action` — what happens on right-click in the terminal.
enum RightClickAction: String, CaseIterable, Identifiable, Hashable {
    case contextMenu = "context-menu"
    case paste
    case copy
    case copyOrPaste = "copy-or-paste"
    case ignore

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .contextMenu: "Show context menu"
        case .paste: "Paste"
        case .copy: "Copy selection"
        case .copyOrPaste: "Copy if selected, else paste"
        case .ignore: "Do nothing"
        }
    }
}

/// `scrollbar` — when the scrollbar widget appears.
enum Scrollbar: String, CaseIterable, Identifiable, Hashable {
    case system, never

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .system: "Match system setting"
        case .never: "Never show"
        }
    }
}

// MARK: - General

enum AutoUpdateMode: String, CaseIterable, Identifiable, Hashable {
    case off, check, download

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .check: "Check only"
        case .download: "Download in background"
        }
    }
}

enum AutoUpdateChannel: String, CaseIterable, Identifiable, Hashable {
    case stable, tip

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .stable: "Stable"
        case .tip: "Tip (pre-release)"
        }
    }
}

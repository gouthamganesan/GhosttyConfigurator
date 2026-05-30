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
    case glassRegular = "macos-glass-regular"
    case glassClear = "macos-glass-clear"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .medium: "Medium"
        case .strong: "Strong"
        case .glassRegular: "macOS glass (regular)"
        case .glassClear: "macOS glass (clear)"
        }
    }

    /// Ghostty's `background-blur` accepts `false`, `true`, a radius int, or
    /// (on macOS 26+) the literal `macos-glass-regular` / `macos-glass-clear`.
    /// Our four numeric buckets map to representative radii; the glass values
    /// pass through verbatim.
    var configValue: String {
        switch self {
        case .off: "false"
        case .subtle: "10"
        case .medium: "20"
        case .strong: "40"
        case .glassRegular: "macos-glass-regular"
        case .glassClear: "macos-glass-clear"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "false", "0": self = .off
        case "true": self = .medium
        case "macos-glass-regular": self = .glassRegular
        case "macos-glass-clear": self = .glassClear
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
    case blockHollow = "block_hollow"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .block: "Block"
        case .bar: "Bar"
        case .underline: "Underline"
        case .blockHollow: "Block (hollow)"
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

/// `window-decoration` — controls window chrome rendering. Ghostty also
/// accepts the legacy boolean values `true` (→ auto) and `false` (→ none).
/// We never write those forms, but `init(rawString:)` lets us read configs
/// that do.
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

    init?(rawString: String) {
        switch rawString.lowercased() {
        case "true": self = .auto
        case "false": self = .none
        default:
            guard let value = WindowDecoration(rawValue: rawString) else { return nil }
            self = value
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

// MARK: - Keyboard

/// `macos-shortcuts` — whether macOS Shortcuts.app can drive Ghostty.
/// Tri-state, not a Bool: `ask` (Ghostty prompts on first invocation),
/// `allow` (no prompts), `deny` (Shortcuts blocked outright). Default is
/// `ask`, which we represent by deleting the key entirely so the file
/// stays terse.
enum MacosShortcuts: String, CaseIterable, Identifiable, Hashable {
    case ask, allow, deny

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .ask: "Ask first (default)"
        case .allow: "Allow without prompting"
        case .deny: "Deny"
        }
    }
}

/// `macos-option-as-alt` — whether macOS Option keys behave as Alt/Meta.
/// 5-state model: `default` represents "key absent" (Ghostty's documented
/// default = `false`, but kept distinct so the UI can show "Auto" without
/// writing the key); the remaining four map to the documented raw values.
enum MacosOptionAsAlt: String, CaseIterable, Identifiable, Hashable {
    case `default`
    case off = "false"
    case both = "true"
    case left
    case right

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .default: "Auto (Ghostty default)"
        case .off: "Off"
        case .both: "Both Option keys"
        case .left: "Left Option only"
        case .right: "Right Option only"
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
    case detect, none, bash, zsh, fish, elvish, nushell

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
        case .nushell: "nushell"
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
        case "nushell", "nu": self = .nushell
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
        case .nushell: "Nushell"
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

/// `confirm-close-surface` — tri-state, NOT a Bool. `true` (default) prompts
/// when shell integration believes a process is running; `false` skips all
/// prompts; `always` confirms unconditionally. We treat `true` as the default,
/// so picking it deletes the key.
enum ConfirmCloseSurface: String, CaseIterable, Identifiable, Hashable {
    case whenBusy = "true"
    case never = "false"
    case always

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .whenBusy: "When a process is running (default)"
        case .never: "Never confirm"
        case .always: "Always confirm"
        }
    }
}

/// `macos-dock-drop-behavior` — windowing when a file/folder is dropped on
/// Ghostty's dock icon.
enum MacosDockDropBehavior: String, CaseIterable, Identifiable, Hashable {
    case newTab = "new-tab"
    case newWindow = "new-window"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .newTab: "New tab in current window"
        case .newWindow: "New window"
        }
    }
}

/// `macos-icon` — dock / app-switcher icon variant. Ghostty also exposes
/// `custom` (image at custom path) and `custom-style` (recolour the official
/// icon) which require additional sibling config; the latter unlocks the
/// frame/ghost/screen-colour rows in the UI.
enum MacosIcon: String, CaseIterable, Identifiable, Hashable {
    case official
    case blueprint
    case chalkboard
    case microchip
    case glass
    case holographic
    case paper
    case retro
    case xray
    case custom
    case customStyle = "custom-style"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .official: "Official"
        case .blueprint: "Blueprint"
        case .chalkboard: "Chalkboard"
        case .microchip: "Microchip"
        case .glass: "Glass"
        case .holographic: "Holographic"
        case .paper: "Paper"
        case .retro: "Retro"
        case .xray: "X-ray"
        case .custom: "Custom image…"
        case .customStyle: "Custom style (re-colour official)"
        }
    }
}

/// `macos-icon-frame` — material for the device frame around the icon. Only
/// meaningful when `macos-icon = custom-style`.
enum MacosIconFrame: String, CaseIterable, Identifiable, Hashable {
    case aluminum, beige, plastic, chrome

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .aluminum: "Brushed aluminum"
        case .beige: "Beige (90's)"
        case .plastic: "Glossy plastic"
        case .chrome: "Chrome"
        }
    }
}

// MARK: - Quick Terminal

/// `quick-terminal-position` — where the slide-out terminal docks.
enum QuickTerminalPosition: String, CaseIterable, Identifiable, Hashable {
    case top, bottom, left, right, center

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        case .center: "Center"
        }
    }
}

/// `quick-terminal-screen` — which display the quick terminal opens on. macOS-only.
enum QuickTerminalScreen: String, CaseIterable, Identifiable, Hashable {
    case main
    case mouse
    case macosMenuBar = "macos-menu-bar"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .main: "OS-recommended main screen"
        case .mouse: "Screen under the mouse"
        case .macosMenuBar: "Screen with the menu bar"
        }
    }
}

/// `quick-terminal-space-behavior` — what happens when you switch macOS spaces.
enum QuickTerminalSpaceBehavior: String, CaseIterable, Identifiable, Hashable {
    case move, remain

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .move: "Follow me across spaces"
        case .remain: "Stay on the space it was opened on"
        }
    }
}

/// `notify-on-command-finish` — when to send command-finished notifications.
enum NotifyOnCommandFinish: String, CaseIterable, Identifiable, Hashable {
    case never, unfocused, always

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .never: "Never (default)"
        case .unfocused: "Only when Ghostty is unfocused"
        case .always: "Always"
        }
    }
}

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

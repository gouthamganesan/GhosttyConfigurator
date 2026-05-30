import Foundation

/// Static, hand-curated index of every actionable row across panes. Mirrors
/// what the panes actually render — when a pane gains a row, add an entry
/// here too. The catalog is the source of truth for global search; building
/// it dynamically from view bodies would couple too tightly to SwiftUI internals.
enum SearchCatalog {
    static let rows: [SearchableRow] = [
        // MARK: Appearance

        .init(
            id: "theme",
            pane: .appearance,
            title: "Theme",
            subtitle: "Color palette",
            docKey: "theme",
            keywords: ["color", "palette", "scheme", "dark", "light"]
        ),
        .init(
            id: "theme-pair",
            pane: .appearance,
            title: "Match system appearance",
            subtitle: "Use a light + dark theme pair",
            docKey: "theme",
            keywords: ["auto", "dark mode", "light mode", "system"]
        ),
        .init(
            id: "background-opacity",
            pane: .appearance,
            title: "Background opacity",
            subtitle: "Transparent ↔ Opaque",
            docKey: "background-opacity",
            keywords: ["transparency", "alpha", "translucent"]
        ),
        .init(
            id: "background-blur",
            pane: .appearance,
            title: "Background blur",
            subtitle: "Vibrancy behind the terminal",
            docKey: "background-blur",
            keywords: ["vibrancy", "frost"]
        ),
        .init(
            id: "background",
            pane: .appearance,
            title: "Background color",
            subtitle: "Override the theme's background",
            docKey: "background",
            keywords: ["color", "bg", "hex"]
        ),
        .init(
            id: "foreground",
            pane: .appearance,
            title: "Foreground color",
            subtitle: "Override the theme's text color",
            docKey: "foreground",
            keywords: ["color", "fg", "text", "hex"]
        ),
        .init(
            id: "cursor-color",
            pane: .appearance,
            title: "Cursor color",
            docKey: "cursor-color",
            keywords: ["caret", "color"]
        ),
        .init(
            id: "selection-background",
            pane: .appearance,
            title: "Selection background",
            docKey: "selection-background",
            keywords: ["highlight", "color"]
        ),
        .init(
            id: "selection-foreground",
            pane: .appearance,
            title: "Selection foreground",
            docKey: "selection-foreground",
            keywords: ["highlight", "text", "color"]
        ),
        .init(
            id: "bold-color",
            pane: .appearance,
            title: "Bold color",
            subtitle: "Color used for bold text",
            docKey: "bold-color",
            keywords: ["bright", "weight", "color"]
        ),
        .init(
            id: "minimum-contrast",
            pane: .appearance,
            title: "Minimum contrast",
            subtitle: "Enforce fg/bg contrast ratio",
            docKey: "minimum-contrast",
            keywords: ["accessibility", "wcag", "contrast"]
        ),

        // MARK: Window

        .init(
            id: "macos-titlebar-style",
            pane: .window,
            title: "Title bar style",
            docKey: "macos-titlebar-style",
            keywords: ["chrome", "header"]
        ),
        .init(
            id: "macos-window-buttons",
            pane: .window,
            title: "Window buttons",
            subtitle: "Traffic-light visibility",
            docKey: "macos-window-buttons",
            keywords: ["traffic lights", "close", "minimize", "zoom"]
        ),
        .init(
            id: "window-decoration",
            pane: .window,
            title: "Window decoration",
            docKey: "window-decoration",
            keywords: ["frame", "border", "borderless", "chrome"]
        ),
        .init(
            id: "macos-window-shadow",
            pane: .window,
            title: "Window shadow",
            docKey: "macos-window-shadow"
        ),
        .init(
            id: "window-padding-x",
            pane: .window,
            title: "Horizontal padding",
            docKey: "window-padding-x",
            keywords: ["margin", "space", "gutter"]
        ),
        .init(
            id: "window-padding-y",
            pane: .window,
            title: "Vertical padding",
            docKey: "window-padding-y",
            keywords: ["margin", "space", "gutter"]
        ),
        .init(
            id: "window-padding-balance",
            pane: .window,
            title: "Balance padding",
            docKey: "window-padding-balance"
        ),
        .init(
            id: "macos-non-native-fullscreen",
            pane: .window,
            title: "Non-native fullscreen",
            docKey: "macos-non-native-fullscreen",
            keywords: ["fullscreen", "spaces"]
        ),
        .init(
            id: "window-save-state",
            pane: .window,
            title: "Restore windows",
            subtitle: "Persist window state across launches",
            docKey: "window-save-state",
            keywords: ["session", "reopen", "state"]
        ),
        .init(
            id: "window-title-font-family",
            pane: .window,
            title: "Title font",
            subtitle: "Font for the window title bar",
            docKey: "window-title-font-family",
            keywords: ["typeface", "titlebar", "font"]
        ),
        .init(
            id: "window-width",
            pane: .window,
            title: "Initial width",
            subtitle: "Columns at launch",
            docKey: "window-width",
            keywords: ["size", "columns", "geometry"]
        ),
        .init(
            id: "window-height",
            pane: .window,
            title: "Initial height",
            subtitle: "Rows at launch",
            docKey: "window-height",
            keywords: ["size", "rows", "geometry"]
        ),
        .init(
            id: "macos-titlebar-proxy-icon",
            pane: .window,
            title: "Proxy icon",
            subtitle: "Folder icon in the title bar",
            docKey: "macos-titlebar-proxy-icon",
            keywords: ["title", "folder", "icon"]
        ),
        .init(
            id: "window-padding-color",
            pane: .window,
            title: "Padding color",
            subtitle: "Background, extend, or always extend",
            docKey: "window-padding-color",
            keywords: ["padding", "gutter", "color"]
        ),
        .init(
            id: "window-new-tab-position",
            pane: .window,
            title: "New tab position",
            docKey: "window-new-tab-position",
            keywords: ["tab", "insert"]
        ),
        .init(
            id: "resize-overlay",
            pane: .window,
            title: "Resize overlay",
            subtitle: "When to show resize popup",
            docKey: "resize-overlay",
            keywords: ["overlay", "resize", "popup"]
        ),

        // MARK: Font

        .init(
            id: "font-family",
            pane: .font,
            title: "Font family",
            docKey: "font-family",
            keywords: ["typeface", "monospace"]
        ),
        .init(
            id: "font-size",
            pane: .font,
            title: "Font size",
            docKey: "font-size",
            keywords: ["zoom", "text size"]
        ),
        .init(
            id: "font-feature-liga",
            pane: .font,
            title: "Standard ligatures",
            subtitle: "OpenType `liga` feature",
            docKey: "font-feature",
            keywords: ["ligatures", "opentype"]
        ),
        .init(
            id: "font-feature-calt",
            pane: .font,
            title: "Contextual alternates",
            subtitle: "OpenType `calt` feature",
            docKey: "font-feature",
            keywords: ["ligatures", "opentype"]
        ),
        .init(
            id: "font-thicken",
            pane: .font,
            title: "Thicken strokes",
            subtitle: "Bold text on non-Retina",
            docKey: "font-thicken",
            keywords: ["bold", "weight"]
        ),
        .init(
            id: "font-family-bold",
            pane: .font,
            title: "Bold font",
            subtitle: "Override for bold weight",
            docKey: "font-family-bold",
            keywords: ["typeface", "bold"]
        ),
        .init(
            id: "font-family-italic",
            pane: .font,
            title: "Italic font",
            subtitle: "Override for italic slant",
            docKey: "font-family-italic",
            keywords: ["typeface", "italic", "oblique"]
        ),
        .init(
            id: "font-family-bold-italic",
            pane: .font,
            title: "Bold-italic font",
            docKey: "font-family-bold-italic",
            keywords: ["typeface", "bold", "italic"]
        ),
        .init(
            id: "font-synthetic-style",
            pane: .font,
            title: "Synthesize missing styles",
            subtitle: "Fake bold/italic when font lacks them",
            docKey: "font-synthetic-style",
            keywords: ["bold", "italic", "fake"]
        ),
        .init(
            id: "font-thicken-strength",
            pane: .font,
            title: "Thicken strength",
            subtitle: "0 = lightest, 255 = heaviest",
            docKey: "font-thicken-strength",
            keywords: ["bold", "weight", "stroke"]
        ),
        .init(
            id: "font-feature-dlig",
            pane: .font,
            title: "Discretionary ligatures",
            subtitle: "OpenType `dlig` feature",
            docKey: "font-feature",
            keywords: ["ligatures", "opentype", "dlig"]
        ),
        .init(
            id: "font-feature-hlig",
            pane: .font,
            title: "Historical ligatures",
            subtitle: "OpenType `hlig` feature",
            docKey: "font-feature",
            keywords: ["ligatures", "opentype", "hlig"]
        ),
        .init(
            id: "font-numerals",
            pane: .font,
            title: "Numerals",
            subtitle: "Tabular, proportional, old-style, lining",
            docKey: "font-feature",
            keywords: ["digits", "tabular", "proportional", "tnum", "pnum", "onum", "lnum"]
        ),

        // MARK: Cursor

        .init(
            id: "cursor-style",
            pane: .cursor,
            title: "Cursor style",
            subtitle: "Block, bar, underline",
            docKey: "cursor-style",
            keywords: ["caret", "shape"]
        ),
        .init(
            id: "cursor-style-blink",
            pane: .cursor,
            title: "Blink cursor",
            docKey: "cursor-style-blink",
            keywords: ["blinking", "flash"]
        ),
        .init(
            id: "cursor-text",
            pane: .cursor,
            title: "Cursor text color",
            subtitle: "Text drawn under the cursor",
            docKey: "cursor-text",
            keywords: ["color", "inverted", "cursor"]
        ),
        .init(
            id: "cursor-opacity",
            pane: .cursor,
            title: "Cursor opacity",
            docKey: "cursor-opacity",
            keywords: ["transparency", "alpha"]
        ),
        .init(
            id: "cursor-click-to-move",
            pane: .cursor,
            title: "Click to move cursor",
            docKey: "cursor-click-to-move",
            keywords: ["mouse", "click"]
        ),
        .init(
            id: "mouse-hide-while-typing",
            pane: .cursor,
            title: "Hide mouse while typing",
            docKey: "mouse-hide-while-typing"
        ),

        // MARK: Keyboard

        .init(
            id: "keybind",
            pane: .keyboard,
            title: "Custom shortcuts",
            subtitle: "Add and edit key bindings",
            docKey: "keybind",
            keywords: ["hotkey", "shortcut", "binding", "keyboard", "kbd"]
        ),
        .init(
            id: "macos-option-as-alt",
            pane: .keyboard,
            title: "Option as Alt",
            subtitle: "Send Alt/Meta to terminal programs",
            docKey: "macos-option-as-alt",
            keywords: ["option", "alt", "meta", "vim", "emacs", "modifier"]
        ),
        .init(
            id: "macos-shortcuts",
            pane: .keyboard,
            title: "macOS menu shortcuts",
            subtitle: "Allow menu items to receive shortcuts",
            docKey: "macos-shortcuts",
            keywords: ["menu", "shortcut", "macos", "keybinding"]
        ),

        // MARK: Shell

        .init(
            id: "shell-integration",
            pane: .shell,
            title: "Shell integration",
            subtitle: "Auto, off, or a specific shell",
            docKey: "shell-integration",
            keywords: ["zsh", "bash", "fish", "elvish"]
        ),
        .init(
            id: "shell-feature-cursor",
            pane: .shell,
            title: "Update cursor shape",
            docKey: "shell-integration-features"
        ),
        .init(
            id: "shell-feature-sudo",
            pane: .shell,
            title: "Quote arguments to sudo",
            docKey: "shell-integration-features"
        ),
        .init(
            id: "shell-feature-title",
            pane: .shell,
            title: "Update window title from shell",
            docKey: "shell-integration-features",
            keywords: ["title"]
        ),
        .init(
            id: "shell-feature-ssh-env",
            pane: .shell,
            title: "Forward SSH environment",
            subtitle: "TERM, COLORTERM, TERM_PROGRAM over SSH",
            docKey: "shell-integration-features",
            keywords: ["ssh", "remote", "term"]
        ),
        .init(
            id: "shell-feature-ssh-terminfo",
            pane: .shell,
            title: "Install terminfo on SSH",
            docKey: "shell-integration-features",
            keywords: ["ssh", "remote", "terminfo", "xterm-ghostty"]
        ),
        .init(
            id: "initial-command",
            pane: .shell,
            title: "Initial command",
            subtitle: "Runs only on first surface",
            docKey: "initial-command",
            keywords: ["startup", "command", "first launch"]
        ),
        .init(
            id: "env",
            pane: .shell,
            title: "Environment variables",
            subtitle: "KEY=VALUE list passed to launched commands",
            docKey: "env",
            keywords: ["env", "environment", "vars"]
        ),
        .init(
            id: "command",
            pane: .shell,
            title: "Command",
            subtitle: "Override the launched shell",
            docKey: "command",
            keywords: ["shell", "exec", "startup"]
        ),
        .init(
            id: "working-directory",
            pane: .shell,
            title: "Working directory",
            subtitle: "Initial cwd",
            docKey: "working-directory",
            keywords: ["cwd", "pwd", "directory"]
        ),
        .init(
            id: "term",
            pane: .shell,
            title: "TERM",
            subtitle: "Terminfo identifier",
            docKey: "term",
            keywords: ["terminfo", "xterm"]
        ),

        // MARK: Clipboard & Mouse

        .init(
            id: "clipboard-read",
            pane: .clipboardMouse,
            title: "Allow reading clipboard",
            docKey: "clipboard-read",
            keywords: ["paste", "permission", "security"]
        ),
        .init(
            id: "clipboard-write",
            pane: .clipboardMouse,
            title: "Allow writing clipboard",
            docKey: "clipboard-write",
            keywords: ["copy", "permission", "security"]
        ),
        .init(
            id: "clipboard-paste-protection",
            pane: .clipboardMouse,
            title: "Paste protection",
            subtitle: "Warn before risky pastes",
            docKey: "clipboard-paste-protection",
            keywords: ["security", "newline", "phishing"]
        ),
        .init(
            id: "clipboard-trim-trailing-spaces",
            pane: .clipboardMouse,
            title: "Trim trailing spaces on paste",
            docKey: "clipboard-trim-trailing-spaces"
        ),
        .init(
            id: "copy-on-select",
            pane: .clipboardMouse,
            title: "Copy on select",
            docKey: "copy-on-select",
            keywords: ["copy", "selection"]
        ),
        .init(
            id: "selection-clear-on-typing",
            pane: .clipboardMouse,
            title: "Clear selection when typing",
            docKey: "selection-clear-on-typing"
        ),
        .init(
            id: "mouse-shift-capture",
            pane: .clipboardMouse,
            title: "Shift capture",
            subtitle: "Shift+click selection vs. forward",
            docKey: "mouse-shift-capture"
        ),
        .init(
            id: "mouse-scroll-multiplier",
            pane: .clipboardMouse,
            title: "Scroll multiplier",
            docKey: "mouse-scroll-multiplier",
            keywords: ["wheel", "trackpad", "scroll speed"]
        ),
        .init(
            id: "mouse-reporting",
            pane: .clipboardMouse,
            title: "Forward mouse events to apps",
            docKey: "mouse-reporting",
            keywords: ["xterm-mouse", "vim mouse", "tmux mouse"]
        ),
        .init(
            id: "focus-follows-mouse",
            pane: .clipboardMouse,
            title: "Focus follows mouse",
            docKey: "focus-follows-mouse",
            keywords: ["sloppy focus"]
        ),
        .init(
            id: "selection-clear-on-copy",
            pane: .clipboardMouse,
            title: "Clear selection after copy",
            docKey: "selection-clear-on-copy",
            keywords: ["copy", "selection"]
        ),
        .init(
            id: "selection-word-chars",
            pane: .clipboardMouse,
            title: "Word boundaries",
            subtitle: "Characters that stop double-click selection",
            docKey: "selection-word-chars",
            keywords: ["word", "boundary", "double-click"]
        ),
        .init(
            id: "clipboard-paste-bracketed-safe",
            pane: .clipboardMouse,
            title: "Trust bracketed pastes",
            subtitle: "Skip prompt when program opts into bracketed mode",
            docKey: "clipboard-paste-bracketed-safe",
            keywords: ["paste", "bracketed", "security"]
        ),
        .init(
            id: "right-click-action",
            pane: .clipboardMouse,
            title: "Right-click action",
            subtitle: "Context menu, paste, copy, or ignore",
            docKey: "right-click-action",
            keywords: ["right-click", "context menu", "paste"]
        ),
        .init(
            id: "scrollback-limit",
            pane: .clipboardMouse,
            title: "Scrollback buffer size",
            subtitle: "In MB; default ~10 MB",
            docKey: "scrollback-limit",
            keywords: ["scrollback", "history", "memory", "buffer"]
        ),
        .init(
            id: "scrollbar",
            pane: .clipboardMouse,
            title: "Scrollbar visibility",
            docKey: "scrollbar",
            keywords: ["scrollbar", "gutter"]
        ),
        .init(
            id: "scroll-to-bottom-keystroke",
            pane: .clipboardMouse,
            title: "Jump to bottom on keystroke",
            docKey: "scroll-to-bottom (keystroke)",
            keywords: ["scroll", "jump", "bottom"]
        ),
        .init(
            id: "scroll-to-bottom-output",
            pane: .clipboardMouse,
            title: "Jump to bottom on new output",
            docKey: "scroll-to-bottom (output)",
            keywords: ["scroll", "jump", "bottom", "output"]
        ),

        // MARK: General

        .init(
            id: "auto-update",
            pane: .general,
            title: "Automatic updates",
            docKey: "auto-update",
            keywords: ["sparkle", "update"]
        ),
        .init(
            id: "auto-update-channel",
            pane: .general,
            title: "Update channel",
            subtitle: "Stable or Tip",
            docKey: "auto-update-channel",
            keywords: ["beta", "nightly", "tip"]
        ),
        .init(
            id: "confirm-close-surface",
            pane: .general,
            title: "Confirm before closing",
            docKey: "confirm-close-surface",
            keywords: ["quit", "exit"]
        ),
        .init(
            id: "quit-after-last-window-closed",
            pane: .general,
            title: "Quit when last window closes",
            docKey: "quit-after-last-window-closed",
            keywords: ["dock"]
        ),
        .init(
            id: "desktop-notifications",
            pane: .general,
            title: "Desktop notifications",
            docKey: "desktop-notifications",
            keywords: ["notify", "alert"]
        ),
        .init(
            id: "bell-audio-volume",
            pane: .general,
            title: "Bell volume",
            docKey: "bell-audio-volume",
            keywords: ["sound", "audio", "alert"]
        ),
        .init(
            id: "macos-auto-secure-input",
            pane: .general,
            title: "Enable secure input at password prompts",
            docKey: "macos-auto-secure-input",
            keywords: ["security", "password"]
        ),
        .init(
            id: "macos-secure-input-indication",
            pane: .general,
            title: "Show secure-input indicator",
            docKey: "macos-secure-input-indication",
            keywords: ["security", "indicator"]
        ),
        .init(
            id: "quit-after-last-window-closed-delay",
            pane: .general,
            title: "Quit delay",
            subtitle: "How long to stay running after the last window closes",
            docKey: "quit-after-last-window-closed-delay",
            keywords: ["quit", "delay", "duration", "idle"]
        ),
        .init(
            id: "macos-applescript",
            pane: .general,
            title: "AppleScript integration",
            docKey: "macos-applescript",
            keywords: ["applescript", "automation", "scripting"]
        ),
        .init(
            id: "macos-dock-drop-behavior",
            pane: .general,
            title: "Dock drop behaviour",
            subtitle: "What happens when you drop files on Ghostty's dock icon",
            docKey: "macos-dock-drop-behavior",
            keywords: ["dock", "drag", "drop", "tab", "window"]
        ),
        .init(
            id: "macos-icon",
            pane: .general,
            title: "Dock icon",
            subtitle: "Official, alternates, or a custom style",
            docKey: "macos-icon",
            keywords: ["dock", "icon", "appearance", "blueprint", "retro"]
        ),
        .init(
            id: "macos-icon-frame",
            pane: .general,
            title: "Icon frame material",
            docKey: "macos-icon-frame",
            keywords: ["icon", "frame", "aluminum", "chrome", "beige", "plastic"]
        ),
        .init(
            id: "macos-icon-ghost-color",
            pane: .general,
            title: "Icon ghost colour",
            docKey: "macos-icon-ghost-color",
            keywords: ["icon", "color", "ghost"]
        ),
        .init(
            id: "macos-icon-screen-color",
            pane: .general,
            title: "Icon screen gradient",
            docKey: "macos-icon-screen-color",
            keywords: ["icon", "color", "gradient", "screen"]
        ),
        .init(
            id: "launch-at-login",
            pane: .general,
            title: "Launch Ghostty at login",
            subtitle: "Open via System Settings → Login Items",
            keywords: ["login", "startup", "autostart"]
        ),
        .init(
            id: "check-for-updates-now",
            pane: .general,
            title: "Check for updates now",
            keywords: ["update", "check", "sparkle"]
        ),

        // MARK: About

        .init(
            id: "about",
            pane: .about,
            title: "About",
            subtitle: "Version and credits",
            keywords: ["version", "credits", "license"]
        )
    ]
}

import Foundation

/// Friendly-label translation for Ghostty's 80 keybind action verbs.
/// Source: `docs/03-ux-principles.md` starter table.
///
/// The configurator displays the friendly label everywhere; the raw verb is
/// only ever shown via the DocTooltip's "View raw" affordance. Falls back to
/// a title-cased version of the verb when the dictionary doesn't know it.
enum ActionLabels {
    /// Categorical grouping for the action picker.
    enum Category: String, CaseIterable, Identifiable {
        case clipboard, search, font, screen, files
        case tabs, splits, windowState, modes, config, lifecycle, custom

        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .clipboard: "Clipboard"
            case .search: "Search"
            case .font: "Font"
            case .screen: "Screen & Scrolling"
            case .files: "Save to file"
            case .tabs: "Tabs"
            case .splits: "Splits"
            case .windowState: "Window"
            case .modes: "Modes"
            case .config: "Config & App"
            case .lifecycle: "Lifecycle"
            case .custom: "Custom escape / text"
            }
        }
    }

    struct Entry: Hashable, Identifiable {
        let verb: String
        let label: String
        let description: String
        let category: Category
        /// True if the action takes a required parameter (e.g. `set_font_size:14`).
        let needsParameter: Bool

        var id: String {
            verb
        }
    }

    /// Catalog ordered as it appears in the action-picker list.
    static let catalog: [Entry] = [
        // Clipboard
        Entry(
            verb: "copy_to_clipboard",
            label: "Copy",
            description: "Copy the selected text to the system clipboard.",
            category: .clipboard,
            needsParameter: false
        ),
        Entry(
            verb: "paste_from_clipboard",
            label: "Paste",
            description: "Paste from the system clipboard.",
            category: .clipboard,
            needsParameter: false
        ),
        Entry(
            verb: "paste_from_selection",
            label: "Paste from selection",
            description: "Paste from the primary selection.",
            category: .clipboard,
            needsParameter: false
        ),
        Entry(
            verb: "copy_url_to_clipboard",
            label: "Copy URL",
            description: "Copy a URL detected near the cursor.",
            category: .clipboard,
            needsParameter: false
        ),
        Entry(
            verb: "copy_title_to_clipboard",
            label: "Copy terminal title",
            description: "Copy the current terminal title.",
            category: .clipboard,
            needsParameter: false
        ),

        // Search
        Entry(
            verb: "search",
            label: "Find",
            description: "Open search in the current terminal.",
            category: .search,
            needsParameter: false
        ),
        Entry(
            verb: "search_selection",
            label: "Find selected text",
            description: "Search for the currently selected text.",
            category: .search,
            needsParameter: false
        ),
        Entry(
            verb: "navigate_search",
            label: "Navigate search",
            description: "Jump to next/previous search result. Param: next or previous.",
            category: .search,
            needsParameter: true
        ),

        // Font
        Entry(
            verb: "increase_font_size",
            label: "Zoom in",
            description: "Increase font size.",
            category: .font,
            needsParameter: false
        ),
        Entry(
            verb: "decrease_font_size",
            label: "Zoom out",
            description: "Decrease font size.",
            category: .font,
            needsParameter: false
        ),
        Entry(
            verb: "reset_font_size",
            label: "Reset zoom",
            description: "Restore the configured font size.",
            category: .font,
            needsParameter: false
        ),
        Entry(
            verb: "set_font_size",
            label: "Set font size…",
            description: "Set font size to a specific point value.",
            category: .font,
            needsParameter: true
        ),

        // Screen & scrolling
        Entry(
            verb: "clear_screen",
            label: "Clear screen",
            description: "Clear the visible terminal contents.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "select_all",
            label: "Select all",
            description: "Select all visible text.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "scroll_to_top",
            label: "Scroll to top",
            description: "Scroll to the top of the scrollback.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "scroll_to_bottom",
            label: "Scroll to bottom",
            description: "Scroll to the bottom of the scrollback.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "scroll_to_selection",
            label: "Scroll to selection",
            description: "Scroll the view to the current selection.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "scroll_page_up",
            label: "Scroll page up",
            description: "Scroll up by one page.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "scroll_page_down",
            label: "Scroll page down",
            description: "Scroll down by one page.",
            category: .screen,
            needsParameter: false
        ),
        Entry(
            verb: "jump_to_prompt",
            label: "Jump to prompt…",
            description: "Jump forward/back N shell prompts (requires shell integration).",
            category: .screen,
            needsParameter: true
        ),

        // Save to file
        Entry(
            verb: "write_scrollback_file",
            label: "Save scrollback to file",
            description: "Save the entire scrollback to a temp file. Param: open, paste, or copy.",
            category: .files,
            needsParameter: true
        ),
        Entry(
            verb: "write_screen_file",
            label: "Save screen to file",
            description: "Save the visible screen to a temp file. Param: open, paste, or copy.",
            category: .files,
            needsParameter: true
        ),
        Entry(
            verb: "write_selection_file",
            label: "Save selection to file",
            description: "Save the selected text to a temp file. Param: open, paste, or copy.",
            category: .files,
            needsParameter: true
        ),

        // Tabs
        Entry(
            verb: "new_tab",
            label: "New tab",
            description: "Open a new tab in the current window.",
            category: .tabs,
            needsParameter: false
        ),
        Entry(
            verb: "previous_tab",
            label: "Previous tab",
            description: "Switch to the previous tab.",
            category: .tabs,
            needsParameter: false
        ),
        Entry(
            verb: "next_tab",
            label: "Next tab",
            description: "Switch to the next tab.",
            category: .tabs,
            needsParameter: false
        ),
        Entry(
            verb: "last_tab",
            label: "Last tab",
            description: "Switch to the most recently used tab.",
            category: .tabs,
            needsParameter: false
        ),
        Entry(
            verb: "goto_tab",
            label: "Go to tab…",
            description: "Switch to a specific tab (1–9).",
            category: .tabs,
            needsParameter: true
        ),
        Entry(
            verb: "move_tab",
            label: "Move tab…",
            description: "Move the current tab by N positions (+1, -1, etc.).",
            category: .tabs,
            needsParameter: true
        ),
        Entry(
            verb: "prompt_tab_title",
            label: "Rename tab…",
            description: "Open a dialog to rename the current tab.",
            category: .tabs,
            needsParameter: false
        ),
        Entry(
            verb: "set_tab_title",
            label: "Set tab title…",
            description: "Set the tab title to the given string.",
            category: .tabs,
            needsParameter: true
        ),
        Entry(
            verb: "close_tab",
            label: "Close tab",
            description: "Close the current tab.",
            category: .tabs,
            needsParameter: false
        ),

        // Splits
        Entry(
            verb: "new_split",
            label: "New split…",
            description: "Create a split. Param: right, down, left, up, or auto.",
            category: .splits,
            needsParameter: true
        ),
        Entry(
            verb: "goto_split",
            label: "Focus split…",
            description: "Move focus between splits. Param: next, previous, up/down/left/right.",
            category: .splits,
            needsParameter: true
        ),
        Entry(
            verb: "toggle_split_zoom",
            label: "Zoom split",
            description: "Toggle full-window focus on the current split.",
            category: .splits,
            needsParameter: false
        ),
        Entry(
            verb: "equalize_splits",
            label: "Equalize splits",
            description: "Reset all splits to equal size.",
            category: .splits,
            needsParameter: false
        ),
        Entry(
            verb: "resize_split",
            label: "Resize split…",
            description: "Resize a split by a number of pixels.",
            category: .splits,
            needsParameter: true
        ),

        // Window state
        Entry(
            verb: "new_window",
            label: "New window",
            description: "Open a new Ghostty window.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "close_window",
            label: "Close window",
            description: "Close the current window.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "close_all_windows",
            label: "Close all windows",
            description: "Close every open Ghostty window.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "close_surface",
            label: "Close terminal",
            description: "Close the current terminal surface.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_maximize",
            label: "Maximize window",
            description: "Toggle the window's maximize state.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_fullscreen",
            label: "Fullscreen",
            description: "Toggle fullscreen mode.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_window_decorations",
            label: "Window decorations",
            description: "Toggle the window's title bar and borders.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_window_float_on_top",
            label: "Always on top",
            description: "Toggle window floating above other apps.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_background_opacity",
            label: "Toggle opacity",
            description: "Toggle between opaque and configured opacity.",
            category: .windowState,
            needsParameter: false
        ),
        Entry(
            verb: "reset_window_size",
            label: "Reset window size",
            description: "Restore the window to its default size.",
            category: .windowState,
            needsParameter: false
        ),

        // Modes
        Entry(
            verb: "toggle_secure_input",
            label: "Secure input",
            description: "Toggle secure keyboard input mode.",
            category: .modes,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_readonly",
            label: "Read-only mode",
            description: "Toggle read-only mode for the current terminal.",
            category: .modes,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_mouse_reporting",
            label: "Mouse reporting",
            description: "Toggle whether terminal apps receive mouse events.",
            category: .modes,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_command_palette",
            label: "Command palette",
            description: "Open the command palette.",
            category: .modes,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_quick_terminal",
            label: "Quick terminal",
            description: "Toggle the drop-down quick terminal.",
            category: .modes,
            needsParameter: false
        ),
        Entry(
            verb: "toggle_visibility",
            label: "Show/hide Ghostty",
            description: "Toggle Ghostty's visibility.",
            category: .modes,
            needsParameter: false
        ),

        // Config & app
        Entry(
            verb: "reload_config",
            label: "Reload configuration",
            description: "Re-read Ghostty's config file.",
            category: .config,
            needsParameter: false
        ),
        Entry(
            verb: "open_config",
            label: "Open config file",
            description: "Open the config file in your default editor.",
            category: .config,
            needsParameter: false
        ),
        Entry(
            verb: "check_for_updates",
            label: "Check for updates",
            description: "Manually check for new Ghostty versions.",
            category: .config,
            needsParameter: false
        ),
        Entry(
            verb: "inspector",
            label: "Inspector",
            description: "Toggle/show/hide the Ghostty inspector. Param: toggle, show, or hide.",
            category: .config,
            needsParameter: true
        ),
        Entry(
            verb: "reset",
            label: "Reset terminal",
            description: "Reset the terminal state.",
            category: .config,
            needsParameter: false
        ),

        // Lifecycle
        Entry(
            verb: "undo",
            label: "Undo",
            description: "Restore the most recently closed tab/window.",
            category: .lifecycle,
            needsParameter: false
        ),
        Entry(
            verb: "redo",
            label: "Redo",
            description: "Re-close after an undo.",
            category: .lifecycle,
            needsParameter: false
        ),

        // Custom escape / text
        Entry(
            verb: "text",
            label: "Send text…",
            description: "Send literal text to the terminal.",
            category: .custom,
            needsParameter: true
        ),
        Entry(
            verb: "csi",
            label: "Send CSI sequence…",
            description: "Send a literal CSI escape sequence.",
            category: .custom,
            needsParameter: true
        ),
        Entry(
            verb: "esc",
            label: "Send ESC sequence…",
            description: "Send a literal ESC sequence.",
            category: .custom,
            needsParameter: true
        ),
        Entry(
            verb: "cursor_key",
            label: "Cursor key…",
            description: "Send a cursor key event. Param: up, down, left, or right.",
            category: .custom,
            needsParameter: true
        ),
        Entry(
            verb: "unbind",
            label: "Remove default binding",
            description: "Remove a default binding for this trigger.",
            category: .custom,
            needsParameter: false
        ),
        Entry(
            verb: "ignore",
            label: "Ignore",
            description: "Do nothing — useful for shadowing a default binding.",
            category: .custom,
            needsParameter: false
        )
    ]

    /// Look up the friendly label for a verb. Falls back to a title-cased
    /// version of the verb for actions not in the catalog.
    static func label(for verb: String) -> String {
        catalog.first { $0.verb == verb }?.label ?? defaultLabel(verb)
    }

    static func entry(for verb: String) -> Entry? {
        catalog.first { $0.verb == verb }
    }

    private static func defaultLabel(_ verb: String) -> String {
        verb.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

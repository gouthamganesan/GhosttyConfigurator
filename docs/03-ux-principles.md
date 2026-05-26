# UX Principles — Non-Negotiable Patterns

These are load-bearing UX rules the configurator must follow. Captured from product direction; treat as P0 requirements, not nice-to-haves. Every pane, every component, every flow must respect these.

If a principle here conflicts with something in [00-PLAN.md](./00-PLAN.md), [01-design-system.md](./01-design-system.md), or [02-information-architecture.md](./02-information-architecture.md), **this doc wins** — patch the others.

---

## Principle 1: Abstract config-syntax from the user

**Rule.** Users never see the raw config syntax (`font-feature = -calt`, `keybind = ctrl+a=search_selection`, `theme = light:X,dark:Y`). They see friendly controls. The text format is an implementation detail.

**Why.** A configurator that just renders the text file with form fields is barely better than `$EDITOR`. The leverage is in *translation* — turning Ghostty's flag/grammar surface into a UI a non-engineer can navigate.

**How to apply.**

| Ghostty raw form | What the user sees |
|---|---|
| `font-feature = -calt`<br>`font-feature = -liga` | **Section: "Font Features"** with checkboxes — "Contextual alternates", "Standard ligatures", "Stylistic sets", etc. Each item with a one-line description. Internally writes the `+` / `-` flags. |
| `keybind = ctrl+a=search_selection` | Row: "Search for selected text" — `⌃A` shortcut chip. The action name `search_selection` is **never** shown to the user. |
| `theme = light:Catppuccin Latte,dark:Catppuccin Mocha` | Toggle "Match system appearance" + two pickers labeled "Light theme" and "Dark theme". User never sees the comma-separated string. |
| `macos-titlebar-style = transparent` | Picker labeled "Titlebar style" with options "Native", "Transparent", "Tabs in titlebar", "Hidden" — descriptive labels, not the raw enum. |
| `background-blur = macos-glass-clear` | Picker: "Off / Subtle / Medium / Strong / Liquid Glass (macOS 26+)". Internally maps. |
| `clipboard-read = ask` | Picker: "Allow", "Deny", "Always ask" — sentence-case prose, not enum-case identifiers. |
| `shell-integration-features = cursor,sudo,no-title` | Three individual toggles ("Update cursor shape", "Quote unsafe arguments to sudo", "Update window title"). Flag-list joining is hidden. |
| `palette = 0=#1d1f21` ... `palette = 15=#c5c8c6` | 16-color palette grid; click to edit individual cells. The indexed-value syntax never appears. |
| `font-codepoint-map = U+1F300-U+1F5FF=Apple Color Emoji` | "Fallback fonts" row → list editor: "For range [picker] use font [picker]". Hex codepoint range is shown but unicode-name annotated. |

**The atomic UI primitive that makes this work:** every row that maps to a non-trivial Ghostty syntax has a **doc tooltip** (see Principle 5) showing the verbatim docs entry. So power users who *want* to see what's being written can hover; everyone else just uses the friendly UI.

**Anti-pattern.** A "TOML editor" tab inside the configurator. The point is to *not* need that. Power users have `$EDITOR` already.

---

## Principle 2: Pending-changes session model

**Rule.** Changes the user makes in the GUI are buffered in-memory, not written to disk on each toggle. A **"Pending Changes" section** appears at the **top of the sidebar** whenever there are unsaved changes, listing every pending edit. The user can review, discard individual changes, or save all.

**Why.** Most configurator interactions involve tweaking 3–8 related settings in one session. Auto-saving on each change means: (a) every toggle triggers a config reload (jarring), (b) no atomic undo, (c) users can't preview a coherent set of changes before committing, (d) accidents are unrecoverable.

The Xcode/VS Code source-control sidebar is the right mental model.

**How to apply.**

- `ConfigStore` keeps two views:
  - `onDisk` — last-read snapshot of the resolved config files
  - `session` — overlay of in-session edits, keyed by `(key, optional list-index)`
  - `effective` — computed: `onDisk` with `session` overrides applied; what the UI reads
- Every row binds to `effective[key]`; setters write to `session`
- Sidebar shows a conditional first section: **"Pending Changes (N)"**
  - Each pending change = one row showing: friendly label (same label as in the source pane) + before → after value preview + which pane it lives in
  - Tap row → navigate to that pane and scroll to the source row
  - Trailing button on row: discard this change (revert to `onDisk`)
  - Section footer: two buttons — `Save all` (primary, accent-color), `Discard all` (plain)
- On `Save all`:
  1. Validate session against schema; show errors inline if any
  2. Write to disk via round-trip parser (preserves comments)
  3. Trigger Ghostty reload (or restart prompt if any change requires it)
  4. `session` clears; "Pending Changes" section disappears
- On window close with unsaved changes: confirm dialog — "Save changes before closing?" / Save / Discard / Cancel
- On Ghostty version change detected mid-session: warn user, offer to re-introspect schema; warn about stale `session` values

**Edge cases:**
- A change that reverts to `onDisk` value should remove itself from `session` (don't show "no-op" as pending)
- Changes to list-typed keys (`keybind`, `font-family`) need a structural diff, not a string diff
- "Save all" should still write even if the user has only one change — no special "single-edit" path

**Keyboard:** `⌘S` = Save all. `⌘Z` / `⌘⇧Z` = undo/redo within the session.

---

## Principle 3: Modification-state indicators (dots)

**Rule.** Every row carries a small colored dot after its label indicating modification state:

- **No dot** — value equals Ghostty's default
- **Blue dot** — value differs from default, persisted to disk
- **Yellow dot** — value modified in current session, not yet saved

**Why.** Users need at-a-glance signal for "what have I customized?" without diffing files. The session-vs-disk distinction makes pending changes visible at the row level, not just in the sidebar Pending Changes section.

**How to apply.**

- Render dot as a 6pt circle to the right of the row label, with 6pt leading gap
- Colors: blue = `Color.accentColor` (NOT hardcoded — adopts user's accent); yellow = `Color.yellow` (or a slightly more subdued `Color(red: 1, green: 0.78, blue: 0.2)` if `.yellow` looks too saturated)
- Precedence: yellow > blue. A row that was already modified from default (blue) AND has a session edit shows yellow.
- Sectional rollup: a section header (e.g. "Colors") gets a count badge "(3)" if any rows inside have non-default values, weighted by yellow if any are session-edits
- Sidebar rollup: a sidebar section (e.g. "Appearance") gets a "(N modified)" subtitle when collapsed-state would warrant it; but in normal expanded state, just a small dot on the row matches the row-level pattern
- Hover/tooltip on the dot reveals: "Modified from default (default: 13)" or "Unsaved change (was 13, now 16; default: 13)"

**Resetting:**
- Right-click on row → context menu: "Reset to default" (if blue or yellow), "Revert to saved" (if yellow only)
- Section header right-click → "Reset all in this section"

**Implementation note:** the default for each key comes from `ghostty +show-config --default --docs` (Phase 2 introspection). Cache it in the schema; refresh on Ghostty upgrade.

---

## Principle 4: Live previews everywhere they make sense

**Rule.** Any setting whose effect is *visible* in the terminal must have a live preview. The user should see the change reflected before clicking Save.

**Why.** Live preview is the configurator's single biggest advantage over `$EDITOR`. The text file *cannot* show you what "Catppuccin Mocha + JetBrains Mono 14pt + 0.95 opacity + 20px blur + cursor blink off" looks like before you reload Ghostty. The GUI can.

**How to apply.** Build one shared `TerminalPreview` component, used everywhere:

- A faux terminal window rendering sample content with realistic structure
- Sample content includes:
  - Shell prompt with cwd (e.g. `~/projects/ghostty $`)
  - Multi-line command output (mimicking `ls -la --color`, `git log --oneline`, etc.)
  - A code snippet with **terminal-style syntax highlighting** (NOT prose; mimic what `bat` or `pygmentize` outputs in a terminal)
  - At least one error line in red (to show "red" palette color)
  - At least one cursor (to show cursor style)
- Preview parameters bound to the same `effective` config state — when the user adjusts opacity, the preview updates in real-time
- Preview should NOT actually render full terminal escape sequences — it's a static layout with parameterized colors/font/cursor

### Per-pane preview placement

| Pane | Preview content |
|---|---|
| **Appearance** | Full terminal preview using current theme + colors + opacity + blur. This is the marquee preview. |
| **Theme Browser** | Same shared component, rendering each theme as a preview tile + a large detail preview when one is focused. |
| **Font** | Preview with focus on character shapes: code snippet, monospace digits row, common ligatures (`=>`, `!=`, `<=`), CJK + emoji line. |
| **Cursor** | Smaller inline preview showing cursor in current style + color + blink rate, alongside a prompt. |
| **Window > Padding** | Mini schematic showing window outline with padding visualized as colored regions. |

### Syntax highlighting in preview code samples

Code snippets in previews must look like real terminal output, **not** a code editor with IDE-style highlighting. That means:

- Use the **terminal palette** for highlighting (the actual ANSI 0–15 colors from the current theme), not a fixed palette
- Match `bat`-style coloring: yellow for strings, blue for keywords, green for comments, red for errors, default fg for identifiers
- Use the configured `font-family` and `font-size` — the preview is a true representation
- No background highlight per line (terminal doesn't do that)
- Optional cursor block at end of last line

**Anti-pattern.** Don't use a SwiftUI code-editor component (like CodeEditor or Highlightr) that renders in a non-terminal style. The preview must look like Ghostty.

---

## Principle 5: Verbatim docs tooltip on every row

**Rule.** Every row that maps to a Ghostty config key has an info button (a small `info.circle` glyph, tertiary color, after the modification dot) that on hover/tap shows the **verbatim docs entry** for that key, sourced from `ghostty +show-config --default --docs` (parsed at introspection time) or the bundled docs.

Tooltip contents:
- Full description from upstream docs (not paraphrased)
- Default value
- Reload behavior badge ("Live", "Restart needed", etc.)
- The raw config key name (in monospace, for users who want to grep the docs themselves)
- Link: "View in Ghostty docs ↗" → opens the relevant page on ghostty.org

**Why.** The friendly-UI translation (Principle 1) is opinionated — sometimes too opinionated. Power users need to verify "is 'Update cursor shape' actually `shell-integration-features = cursor`?" The tooltip is the escape hatch that lets the friendly UI stay clean without losing trust.

**How to apply.**

- Component: `DocTooltip(key: String)` — reads from the cached schema introspection
- Trigger: hover on macOS (NSPopover-style), click on touch. **Don't autoshow** — info icon must be clicked/hovered.
- Tooltip width: ~320pt, content scrollable if long
- Live-fetch fallback: if schema cache doesn't have entry, show "Loading docs…" then resolve via lookup; if still missing, show "See full reference ↗" with the live URL
- Cache invalidation: on Ghostty version change

**Anti-pattern.** Don't write your own description of what each setting does. Let upstream docs be the source of truth — that way they stay correct as Ghostty changes.

---

## Principle 6: Connect to live help from the app

**Rule.** Every external link to Ghostty documentation is one click away. The **About pane** is the canonical place; in-row tooltips (Principle 5) are the contextual entry point.

**About pane links (P0):**

- Ghostty website → https://ghostty.org
- Configuration docs → https://ghostty.org/docs/config
- Full option reference → https://ghostty.org/docs/config/reference
- Keybindings reference → https://ghostty.org/docs/config/keybind
- Keybind actions reference → https://ghostty.org/docs/config/keybind/reference
- Trigger sequences (chords) → https://ghostty.org/docs/config/keybind/sequence
- Themes browser (community) → https://github.com/ghostty-org/ghostty/tree/main/src/config/themes
- Source code → https://github.com/ghostty-org/ghostty
- Report a Ghostty issue → https://github.com/ghostty-org/ghostty/issues
- Configurator source → (your GitHub URL)
- Report a configurator issue → (your GitHub issues URL)

Render as a `Form { Section { ... } }.formStyle(.grouped)` grouping with rows that show `Link("...", destination: URL)` — they pick up the standard macOS blue-link styling.

---

## Component additions required

These extend [01-design-system.md](./01-design-system.md):

### `ModificationIndicator`

```swift
enum ModState { case unchanged, modifiedSaved, modifiedSession }

struct ModificationIndicator: View {
    let state: ModState

    var body: some View {
        Group {
            switch state {
            case .unchanged:        Color.clear
            case .modifiedSaved:    Circle().fill(Color.accentColor)
            case .modifiedSession:  Circle().fill(Color.yellow)
            }
        }
        .frame(width: 6, height: 6)
        .accessibilityLabel(state.accessibilityLabel)
    }
}
```

Used by every row component: place after the label text, with 6pt leading gap.

### `DocTooltip`

```swift
struct DocTooltip: View {
    let key: String
    @State private var isShown = false

    var body: some View {
        Button {
            isShown.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShown, arrowEdge: .leading) {
            DocTooltipContent(key: key)
                .frame(width: 320)
        }
    }
}
```

Used by every row that maps to a Ghostty key. NOT used on app-level rows like "Open at login" that don't have a Ghostty docs entry.

### `RowAffix`

A consolidated trailing-decorator that includes both the modification dot and the doc tooltip, used by all settings rows:

```swift
struct RowAffix: View {
    let modState: ModState
    let docKey: String?

    var body: some View {
        HStack(spacing: 4) {
            ModificationIndicator(state: modState)
            if let docKey { DocTooltip(key: docKey) }
        }
    }
}
```

Place after a row label like this:

```swift
LabeledContent {
    Picker(...)
} label: {
    HStack(spacing: 6) {
        Text("Theme")
        RowAffix(modState: store.modState(for: "theme"), docKey: "theme")
    }
}
```

### `PendingChangesSection`

A new sidebar section that conditionally renders at the top:

```swift
struct PendingChangesSection: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        if !store.session.isEmpty {
            Section {
                ForEach(store.session.entries) { change in
                    PendingChangeRow(change: change)
                }
            } header: {
                HStack {
                    Text("Pending Changes")
                    Spacer()
                    Text("\(store.session.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                HStack {
                    Button("Discard All") { store.discardSession() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save All") { store.saveSession() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
    }
}
```

The sidebar's main `List` becomes:
```swift
List(selection: $selection) {
    PendingChangesSection()
    Section { ForEach(SidebarSection.visualGroup) { row($0) } }
    Section { ForEach(SidebarSection.behaviorGroup) { row($0) } }
    Section { ForEach(SidebarSection.advancedGroup) { row($0) } }
}
```

### `TerminalPreview`

The single shared preview component (Principle 4). Rough sketch:

```swift
struct TerminalPreview: View {
    let palette: [Color]          // 16 ANSI colors
    let background: Color
    let foreground: Color
    let font: Font
    let opacity: Double
    let cursorStyle: CursorStyle
    // ...

    var body: some View {
        ZStack {
            // background with opacity simulation
            // sample lines: prompt, command, output, syntax-highlighted code
            // cursor
        }
        .frame(minWidth: 400, minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

Used in Appearance pane, Theme Browser, Font pane, Cursor pane.

---

## Updates to existing docs

Patch the following sections in other docs to align with these principles:

### Patch to `00-PLAN.md`

- Add to **§6 Design principles** (insert as principle 7+): the five principles above as one-liners pointing to this doc
- Add to **Phase 2** acceptance criteria: "ConfigStore implements the session-overlay model (Principle 2); writes flush only on Save"
- Add to **Phase 3** per-pane checklist: "Every row has `RowAffix` showing modification state + doc tooltip"
- Add to **Phase 4 (Theme Browser)** acceptance: "Uses `TerminalPreview` with terminal-style syntax highlighting (Principle 4)"

### Patch to `01-design-system.md`

- Add to **Core components** list: `ModificationIndicator`, `DocTooltip`, `RowAffix`, `PendingChangesSection`, `TerminalPreview`
- Update every row variant example (6a–6g) to include `RowAffix` in the label HStack
- Add a new section **"Translation principles"** referencing this doc — when wrapping a raw Ghostty key in friendly UI, define the mapping in one place (`ConfigStore` extensions, NOT inline in views)

### Patch to `02-information-architecture.md`

- Change **Font § Features** row from "advanced OpenType features" string input to a **checkbox list** with named features ("Standard ligatures", "Contextual alternates", "Discretionary ligatures", "Stylistic alternates") — internally writing `+`/`-` flags
- Change **Keyboard § Custom keybindings** rendering: each binding shows the **action's friendly label** (e.g. "Search for selected text"), the **shortcut chip** (e.g. ⌘⇧F), and the verbatim action name in the tooltip only — NEVER inline
- Change **Appearance § Theme** to render the "Match system appearance" UI per Principle 1 — toggle + 2 pickers, never a comma-separated string field
- Add to top of doc: link to this UX principles doc + reminder that every row must follow Principles 1, 3, and 5

---

## Friendly-label dictionary (starter set)

Begin a controlled vocabulary for action labels. This grows as keybind editor matures. Stored in `ActionLabels.swift`:

| Ghostty action | Friendly label | One-line description |
|---|---|---|
| `copy_to_clipboard` | Copy | Copy the selected text to the system clipboard |
| `paste_from_clipboard` | Paste | Paste from the system clipboard |
| `paste_from_selection` | Paste from selection | Paste from the primary selection clipboard |
| `search` | Find | Open search in the current terminal |
| `search_selection` | Find selected text | Search for the currently selected text |
| `start_search` / `end_search` | (internal — hide from list) | |
| `navigate_search:next` | Next match | Jump to the next search result |
| `navigate_search:previous` | Previous match | Jump to the previous search result |
| `new_window` | New window | Open a new Ghostty window |
| `new_tab` | New tab | Open a new tab in the current window |
| `close_surface` | Close terminal | Close the current terminal |
| `close_tab` | Close tab | Close the current tab |
| `close_window` | Close window | Close the current window |
| `close_all_windows` | Close all windows | Close every open Ghostty window |
| `new_split:right` | Split right | Create a new split to the right of the current terminal |
| `new_split:down` | Split down | Create a new split below the current terminal |
| `new_split:left` | Split left | Create a new split to the left of the current terminal |
| `new_split:up` | Split up | Create a new split above the current terminal |
| `toggle_split_zoom` | Zoom split | Toggle full-window focus on the current split |
| `equalize_splits` | Equalize splits | Reset all splits in the current window to equal size |
| `goto_split:next` | Next split | Move focus to the next split |
| `goto_split:previous` | Previous split | Move focus to the previous split |
| `goto_split:up/down/left/right` | Move focus up/down/left/right | Move focus to the split in that direction |
| `previous_tab` / `next_tab` | Previous tab / Next tab | — |
| `goto_tab:1..9` | Go to tab 1..9 | — |
| `last_tab` | Last tab | Switch to the most recently used tab |
| `increase_font_size` / `decrease_font_size` / `reset_font_size` | Zoom in / Zoom out / Reset zoom | Change the font size of the current terminal |
| `set_font_size:N` | Set font size… | Set font size to a specific value |
| `clear_screen` | Clear screen | Clear the visible terminal contents |
| `select_all` | Select all | Select all visible text |
| `scroll_to_top` / `scroll_to_bottom` | Scroll to top / Scroll to bottom | — |
| `scroll_page_up` / `scroll_page_down` | Scroll page up / Scroll page down | — |
| `jump_to_prompt:1` / `:-1` | Next prompt / Previous prompt | Requires shell integration |
| `reload_config` | Reload configuration | Re-read Ghostty's config file |
| `open_config` | Open config file | Open the config file in your default editor |
| `check_for_updates` | Check for updates | Manually check for new Ghostty versions |
| `toggle_command_palette` | Command palette | Open the command palette |
| `toggle_quick_terminal` | Quick terminal | Toggle the drop-down quick terminal |
| `toggle_fullscreen` | Fullscreen | Toggle fullscreen mode |
| `toggle_maximize` | Maximize window | Toggle the window's maximize state |
| `toggle_secure_input` | Secure input | Toggle secure keyboard input mode |
| `toggle_readonly` | Read-only mode | Toggle read-only mode for the current terminal |
| `toggle_window_float_on_top` | Always on top | Toggle window floating above other apps |
| `toggle_background_opacity` | Toggle opacity | Toggle between opaque and configured opacity |
| `toggle_window_decorations` | Window decorations | Toggle the window's title bar and borders |
| `toggle_mouse_reporting` | Mouse reporting | Toggle whether terminal apps receive mouse events |
| `inspector:toggle` | Toggle inspector | Open the Ghostty inspector window |
| `undo` / `redo` | Undo / Redo | Restore recently closed tabs or windows |
| `text:...` | Send text | Send literal text to the terminal |
| `csi:...` / `esc:...` | (advanced — show raw with badge "Custom escape sequence") | |
| `cursor_key:up/down/left/right` | Cursor key… | Send a cursor key event |
| `ignore` | (none — represents an unbound action; hide from picker) | |
| `unbind` | Remove default binding | Remove the default binding for this key |
| `prompt_tab_title` / `prompt_surface_title` | Rename tab / Rename terminal | Open a rename dialog |
| `set_tab_title:X` / `set_surface_title:X` | Set tab title… / Set terminal title… | Set the title directly |
| `move_tab:N` | Move tab… | Move the current tab by N positions |
| `toggle_tab_overview` | Tab overview | Show all tabs in a grid (Linux/GTK) |
| `write_scrollback_file:open` | Save scrollback to file | Save the entire scrollback to a temp file and open it |
| `write_screen_file:open` | Save screen to file | Save the visible screen to a temp file and open it |
| `write_selection_file:open` | Save selection to file | Save the selected text to a temp file and open it |
| `*_file:paste` / `:copy` variants | (advanced — disclosed under "Other variants") | |
| `copy_url_to_clipboard` | Copy URL | Copy a URL detected near the cursor |
| `copy_title_to_clipboard` | Copy terminal title | Copy the current terminal title |
| `scroll_to_selection` | Scroll to selection | Scroll the view to the current selection |
| `scroll_to_row:N` | Scroll to row… | Scroll to a specific row number |
| `scroll_page_fractional:F` | Scroll by fraction… | Scroll by a fraction of a page |
| `scroll_page_lines:N` | Scroll by lines… | Scroll by a specific number of lines |
| `adjust_selection:dir` | Adjust selection… | Extend/shrink the current selection |
| `jump_to_prompt:N` | Jump to prompt… | Jump forward/back N shell prompts |
| `reset` | Reset terminal | Reset the terminal state |
| `reset_window_size` | Reset window size | Restore the window to its default size |
| `show_gtk_inspector` / `show_on_screen_keyboard` | (Linux/GTK; hide on macOS) | |
| `toggle_tab_overview` | (Linux/GTK; hide on macOS) | |
| `toggle_visibility` | Show/hide Ghostty | Toggle Ghostty's visibility |
| `end_key_sequence` | End key sequence | Cancel an in-progress chord sequence |
| `chained-actions` | (config flag, not an action) | |

Fall back to a title-cased version of the action name when not in this dictionary; flag the missing entry in dev mode so we keep growing the table.

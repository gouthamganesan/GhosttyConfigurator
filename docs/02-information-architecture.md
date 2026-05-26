# Information Architecture — Sidebar Sections and Per-Pane Rows

Maps Ghostty's ~188 config keys + 80 keybind actions to a System-Settings-style navigation. Priority tags drive what ships in which phase.

> **Read [03-ux-principles.md](./03-ux-principles.md) before implementing any pane.** Every row spec below is shorthand — the actual implementation must (a) abstract raw config syntax into friendly UI (Principle 1), (b) carry modification-state dots and a doc tooltip (Principles 3 + 5), (c) write to `ConfigStore.session` not directly to disk (Principle 2), (d) include a `TerminalPreview` wherever the value is visually rendered (Principle 4). Where this doc shows a raw key in the "Control" column, that's the Ghostty key it maps to — the user does NOT see the key name in the UI.

**Priority tags:**

- **P0** — ship-blocker for v1. Most users will look for this.
- **P1** — polish for v1 or fast-follow v1.1. Improves the experience but not load-bearing.
- **P2** — defer to v2+ or omit entirely. Power-user or rarely-used.
- **HIDE** — omit from GUI entirely; user edits text file. Includes GTK/Linux keys and dangerous low-level toggles.

**Reload tags** (mirrored from research):
- **live** — change applies instantly
- **new** — change applies to new surfaces/windows
- **restart** — requires Ghostty restart
- **partial** — mixed; depends on context

---

## Sidebar layout

8 sections, grouped into 3 visual clusters (matching System Settings' density pattern of small grouped batches separated by gaps).

### Visual group (top)
1. **Appearance** — colors, themes, opacity
2. **Window** — titlebar, padding, decoration, size

### Behavior group (middle)
3. **Font** — family, size, ligatures, metrics
4. **Cursor** — style, color, blink
5. **Shell** — integration, command, working directory
6. **Keyboard** — keybindings + key remaps
7. **Clipboard & Mouse** — selection, paste protection, scroll

### Advanced group (bottom)
8. **General** — app-level (auto-update, notifications, bell, close-confirmations)
9. **Advanced** — adjust-* metrics, custom shaders, env vars

10. **About** — version, links, credits (no Ghostty config keys, app metadata only)

Conditional sections shown only when relevant:
- **Quick Terminal** — only if user has any `quick-terminal-*` key set, OR exposed under General as a sub-page

GTK/Linux keys (`gtk-*`, `linux-*`, `x11-*`) — never shown.

### SF Symbol + tile color per section

| Section | SF Symbol | Tile color |
|---|---|---|
| Appearance | `paintpalette.fill` | `.purple` |
| Window | `macwindow` | `.blue` |
| Font | `textformat` | `.pink` |
| Cursor | `cursorarrow.rays` | `.orange` |
| Shell | `apple.terminal.fill` (or `terminal.fill`) | `Color(.systemGray)` |
| Keyboard | `keyboard.fill` | `.indigo` |
| Clipboard & Mouse | `cursorarrow.click.2` | `.cyan` |
| General | `gearshape.fill` | `.gray` |
| Advanced | `wrench.and.screwdriver.fill` | `Color(.systemGray)` |
| About | `info.circle.fill` | `.blue` |

---

## Pane: Appearance

**Hero card:** "Appearance — Customize colors, themes, and visual style." Icon: `paintpalette.fill` on purple-pink gradient.

### Section: Theme [P0]

Per [Principle 1](./03-ux-principles.md#principle-1-abstract-config-syntax-from-the-user), the user never sees `light:X,dark:Y` syntax. The "Match system appearance" toggle is what reveals/hides the second picker; the configurator joins them into the comma syntax on save.

| Row | Key | Control | Reload |
|---|---|---|---|
| Theme | `theme` (single value) | Disclosure → opens Theme Browser pane; trailing value shows current theme name | live |
| Match system appearance | (derived from `light:X,dark:Y` presence) | Toggle. When ON: row expands to two sub-rows — "Light theme" picker + "Dark theme" picker. When OFF: single picker. | live |

**Footer:** "Browse hundreds of bundled themes or import from iTerm2, Alacritty, or Windows Terminal."

### Section: Colors [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Background | `background` | color | ColorPicker | live |
| Foreground | `foreground` | color | ColorPicker | live |
| Cursor color | `cursor-color` | color (or auto) | ColorPicker with "Auto" toggle | live |
| Selection background | `selection-background` | color (or auto) | ColorPicker with "Auto" toggle | live |
| Selection foreground | `selection-foreground` | color (or auto) | ColorPicker with "Auto" toggle | live |
| Bold text color | `bold-color` | color/enum | Picker: None / Bright / Custom | live |
| Minimum contrast | `minimum-contrast` | float 1.0–21.0 | Slider | live |

### Section: Transparency & Blur [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Background opacity | `background-opacity` | float 0–1 | Slider (Transparent ↔ Opaque) | **restart on macOS** |
| Apply to cells with explicit background | `background-opacity-cells` | bool | Toggle | live |
| Background blur | `background-blur` | int/enum | Picker: Off / Subtle / Medium / Strong / Liquid Glass (macOS 26+) | new |
| Unfocused split opacity | `unfocused-split-opacity` | float 0–1 | Slider | live |

**Footer:** "Background opacity changes require restarting Ghostty on macOS."

### Section: Background Image [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Image | `background-image` | path | File picker | live |
| Opacity | `background-image-opacity` | float 0–1 | Slider | live |
| Position | `background-image-position` | enum | Picker | live |
| Fit | `background-image-fit` | enum | Picker | live |
| Repeat | `background-image-repeat` | bool | Toggle | live |

Disclose this whole section behind a "Use background image" toggle to keep the main pane clean.

### Section: Advanced color [P2]

Disclosed under "Advanced color settings…" disclosure row:

- `palette` (16 ANSI colors + indexed) — palette editor view
- `palette-generate` — toggle
- `cursor-text`, `faint-opacity`, `split-divider-color`
- `search-background`, `search-foreground`, `search-selected-background`, `search-selected-foreground`
- `osc-color-report-format`
- `alpha-blending` — Picker: Native / Linear / Linear-corrected (restart)

---

## Pane: Window

**Hero card:** "Window — Configure the window appearance and behavior." Icon: `macwindow` on blue gradient.

### Section: Titlebar (macOS) [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Style | `macos-titlebar-style` | enum | Picker: Native / Transparent / Tabs / Hidden | new |
| Show proxy icon | `macos-titlebar-proxy-icon` | enum | Toggle (visible/hidden) | partial |
| Show window buttons | `macos-window-buttons` | enum | Toggle (visible/hidden) | new |
| Window shadow | `macos-window-shadow` | bool | Toggle | new |
| Title font | `window-title-font-family` | string | Font picker | live |

### Section: Padding [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Horizontal | `window-padding-x` | int or LEFT,RIGHT | Stepper (with "Different left/right" toggle) | live |
| Vertical | `window-padding-y` | int or TOP,BOTTOM | Stepper (with "Different top/bottom" toggle) | live |
| Balance | `window-padding-balance` | bool | Toggle | live |
| Padding color | `window-padding-color` | enum | Picker: Background / Extend / Always extend | live |

### Section: Initial size & position [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Initial width (cells) | `window-width` | int | Stepper (0 = OS default) | new |
| Initial height (cells) | `window-height` | int | Stepper (0 = OS default) | new |
| Save state | `window-save-state` | enum | Picker: Default / Always / Never | new |
| New tab position | `window-new-tab-position` | enum | Picker: After current / At end | live |

### Section: Fullscreen [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Non-native fullscreen | `macos-non-native-fullscreen` | enum | Picker: Off / On / Visible menu / Padded notch | new |
| Resize overlay | `resize-overlay` | enum | Picker | live |

### Section: Color space [P2]

- `window-colorspace` — Picker: sRGB / Display P3 (restart)
- `window-vsync` — Toggle (restart)

---

## Pane: Font

**Hero card:** "Font — Choose the typeface and rendering for your terminal." Icon: `textformat` on pink-orange gradient.

### Section: Family [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Regular | `font-family` | string (repeatable) | Font picker (multi-select for fallback chain) | live |
| Bold | `font-family-bold` | string | Font picker — "Same as Regular" by default | live |
| Italic | `font-family-italic` | string | Font picker — "Same as Regular" by default | live |
| Bold italic | `font-family-bold-italic` | string | Font picker | live |

**Footer:** "Fallback fonts are used for glyphs the primary font doesn't include (emoji, CJK, etc.)."

### Section: Size & weight [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Size | `font-size` | float | Stepper (0.5pt steps) | live |
| Synthesize bold/italic when missing | `font-synthetic-style` | flag list | Toggle | live |
| Thicker glyphs | `font-thicken` | bool | Toggle (macOS only) | live |
| Thicken strength | `font-thicken-strength` | float | Slider (disclosed when Thicken is on) | live |

### Section: Features [P1]

Per [Principle 1](./03-ux-principles.md#principle-1-abstract-config-syntax-from-the-user), the user sees **named checkboxes** for each font feature, never the raw `+liga` / `-calt` syntax. The checkboxes map to `font-feature` entries internally.

| Row | Key | Control | Reload |
|---|---|---|---|
| **Section header: "Ligatures & Alternates"** | `font-feature` | Checkbox group: "Standard ligatures (`liga`)", "Contextual alternates (`calt`)", "Discretionary ligatures (`dlig`)", "Historical ligatures (`hlig`)" | live |
| **Section header: "Stylistic Variants"** | `font-feature` | Checkbox group: "Stylistic alternates (`salt`)", "Stylistic sets 1–20 (`ss01–ss20`)" — collapsed disclosure listing only sets the current font supports | live |
| **Section header: "Numerals"** | `font-feature` | Picker: "Default / Tabular / Proportional / Old-style / Lining" — internally writes `+tnum`, `+pnum`, `+onum`, `+lnum` | live |
| Variable font axes | `font-variation` | Disclosure → axis sliders, only rendered for variable fonts; populated from font introspection | live |

Each checkbox label uses the human name; the OpenType tag is shown in monospace as a hint. The verbatim docs entry for `font-feature` is in the row's doc tooltip (Principle 5).

### Section: Codepoint mapping [P2]

- `font-codepoint-map` — disclosure to a row-list editor: "U+XXXX–U+YYYY → font name"

### Section: Cell metrics [P2]

Disclosed under "Advanced font metrics…":

All 13 `adjust-*` keys: cell-width, cell-height, font-baseline, underline-position, underline-thickness, strikethrough-position, strikethrough-thickness, overline-position, overline-thickness, cursor-thickness, cursor-height, box-thickness, icon-height.

Render with a live preview pane on the right showing the impact in a sample terminal.

---

## Pane: Cursor

**Hero card:** "Cursor — Customize how the cursor looks and behaves." Icon: `cursorarrow.rays` on orange.

### Section: Style [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Shape | `cursor-style` | enum | Picker: Block / Bar / Underline / Hollow block | live |
| Blink | `cursor-style-blink` | tri-state | Picker: Default / Always blink / Never blink | live |
| Color | `cursor-color` | color | ColorPicker with "Auto" toggle | live |
| Opacity | `cursor-opacity` | float 0–1 | Slider | live |
| Text under cursor | `cursor-text` | color/enum | Picker: Cell background / Cell foreground / Custom | live |

### Section: Behavior [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Click to move cursor (at prompts) | `cursor-click-to-move` | bool | Toggle | live |

**Footer:** "Click-to-move requires shell integration (OSC 133)."

---

## Pane: Shell

**Hero card:** "Shell — Configure how Ghostty launches and integrates with your shell." Icon: `terminal.fill` on gray.

### Section: Default command [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Shell | `command` | string | Picker (zsh/bash/fish/nu/elvish) + Custom | new |
| Initial command (first launch only) | `initial-command` | string | Text field | new |
| Working directory | `working-directory` | string/enum | Picker: Inherit / Home / Custom path | new |
| Environment variables | `env` | KEY=VAL list | Disclosure → list editor | new |
| TERM | `term` | string | Read-only display unless toggled to edit | new |

**Footer:** "Changing the shell only affects new terminal sessions."

### Section: Integration [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Shell integration | `shell-integration` | enum | Picker: Detect / None / bash / zsh / fish / nu / elvish | new |
| Cursor shape from shell | flag in `shell-integration-features` | bool | Toggle | new |
| `sudo` integration | flag | bool | Toggle | new |
| Terminal title from shell | flag | bool | Toggle | new |
| SSH environment forwarding | flag | bool | Toggle | new |
| SSH terminfo forwarding | flag | bool | Toggle | new |

### Section: Behavior [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Confirm close with running command | `confirm-close-surface` | enum | Picker: Always / Only when not at prompt / Never | live |
| Wait after command (debugging) | `wait-after-command` | bool | Toggle (advanced) | new |

---

## Pane: Keyboard

**Hero card:** "Keyboard — Customize keybindings and shortcuts." Icon: `keyboard.fill` on indigo.

**This pane is its own design problem — see [00-PLAN.md Phase 5](./00-PLAN.md#phase-5--keybind-editor-46-days--the-hardest-ui).** For v1 skeleton, render a list of current `keybind` entries with a placeholder "Coming soon — edit text file for now" link.

### Section: Default keybindings [P0]

- Read-only listing from `ghostty +list-keybinds --default`, grouped by category (Tabs, Splits, Search, etc.)

### Section: Custom keybindings [P0 — but the UI is hard]

- List of user-defined `keybind` entries
- Add / edit / delete with the keybind editor sheet (Phase 5)
- **Action display rule** (per [Principle 1](./03-ux-principles.md#principle-1-abstract-config-syntax-from-the-user)): rows show the **friendly action label** from the `ActionLabels` dictionary (e.g. "Search for selected text"), the **shortcut chip** rendered with macOS modifier glyphs (e.g. `⌘⇧F`), and a one-line description as subtext. The raw `search_selection` action verb appears **only** inside the per-row doc tooltip (Principle 5). When a user types `search` in the action picker, the friendly label is what's searched — not the verb.

### Section: Key remapping [P2]

- `key-remap` — list editor: "physical key → key name"

### Section: macOS modifiers [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Option key behavior | `macos-option-as-alt` | enum | Picker: Auto / Off / Left only / Right only / Both | live |
| Use macOS shortcuts | `macos-shortcuts` | bool | Toggle | live |

**Footer:** "Treating Option as Alt enables terminal apps to use it as a modifier, but breaks macOS Option-key character composition (e.g. Option+E → é)."

### Section: Key tables [P2]

- `key-tables` — disclosure to a nested editor (for tmux-style prefix modes)

---

## Pane: Clipboard & Mouse

**Hero card:** "Clipboard & Mouse — Selection, copy/paste, and pointer behavior." Icon: `cursorarrow.click.2` on cyan.

### Section: Selection [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Copy on select | `copy-on-select` | enum/bool | Picker: Off / Selection clipboard / System clipboard | live |
| Clear selection on typing | `selection-clear-on-typing` | bool | Toggle | live |
| Clear selection on copy | `selection-clear-on-copy` | bool | Toggle | live |
| Word characters | `selection-word-chars` | string | Text field (advanced) | live |

### Section: Paste protection [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Warn on dangerous paste | `clipboard-paste-protection` | bool | Toggle | live |
| Trust bracketed paste | `clipboard-paste-bracketed-safe` | bool | Toggle | live |
| Trim trailing spaces | `clipboard-trim-trailing-spaces` | bool | Toggle | live |

**Footer:** "Dangerous paste detection warns when pasted content contains control characters that could execute commands."

### Section: Clipboard permissions (OSC 52) [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Allow terminal apps to read clipboard | `clipboard-read` | enum | Picker: Allow / Deny / Ask | live |
| Allow terminal apps to write clipboard | `clipboard-write` | enum | Picker: Allow / Deny / Ask | live |

### Section: Mouse [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Hide cursor while typing | `mouse-hide-while-typing` | bool | Toggle | live |
| Mouse reporting | `mouse-reporting` | bool | Toggle | live |
| Shift-click to capture | `mouse-shift-capture` | enum | Picker | live |
| Focus follows mouse | `focus-follows-mouse` | bool | Toggle | live |
| Right-click action | `right-click-action` | enum | Picker | live |
| Scroll multiplier | `mouse-scroll-multiplier` | float | Stepper | live |

### Section: Scrollback [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Buffer size | `scrollback-limit` | size | Stepper in MB | new |
| Scroll to bottom on | `scroll-to-bottom` | flag list | Toggle: Keystroke / Output | live |
| Scrollbar | `scrollbar` | enum | Picker | new |

---

## Pane: General

**Hero card:** "General — App-level preferences and system behavior." Icon: `gearshape.fill` on gray.

### Section: Startup [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Open at login | (macOS Launch Services, not a Ghostty key) | bool | Toggle | live |
| Quit when last window closes | `quit-after-last-window-closed` | bool | Toggle | live |
| Quit delay | `quit-after-last-window-closed-delay` | duration | Stepper | live |
| Confirm close window | `confirm-close-surface` | enum | (duplicates Shell pane row — show only here) | live |

### Section: Updates [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Auto-update | `auto-update` | enum | Toggle | live |
| Update channel | `auto-update-channel` | enum | Picker: Stable / Tip | live |
| Check now | (action) | button | Button → `check_for_updates` action | — |

### Section: Notifications [P0]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Notify on command finish | `notify-on-command-finish` | enum | Picker: Off / Always / When unfocused | live |
| After running for | `notify-on-command-finish-after` | duration | Stepper | live |
| Action | `notify-on-command-finish-action` | enum | Picker | live |
| In-app notifications | `app-notifications` | flag list | Multi-toggle | live |

### Section: Bell [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Bell behavior | `bell-features` | flag list | Multi-toggle: System / Audio / Attention / Title / Border | live |
| Audio file | `bell-audio-path` | path | File picker | live |
| Volume | `bell-audio-volume` | float 0–1 | Slider | live |

### Section: macOS [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Auto-enable secure input | `macos-auto-secure-input` | bool | Toggle | live |
| Show secure input indicator | `macos-secure-input-indication` | bool | Toggle | live |
| Allow AppleScript control | `macos-applescript` | enum | Picker | live |
| Dock drop behavior | `macos-dock-drop-behavior` | enum | Picker | live |

### Section: Dock icon [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Icon variant | `macos-icon` | enum | Picker with thumbnails: Official / Blueprint / Chalkboard / Microchip / Glass / Holographic / Paper / Retro / X-Ray / Custom | restart |
| Frame (custom only) | `macos-icon-frame` | enum | Picker: Aluminum / Beige / Plastic / Chrome | restart |
| Ghost color (custom only) | `macos-icon-ghost-color` | color | ColorPicker | restart |
| Screen color (custom only) | `macos-icon-screen-color` | color | ColorPicker | restart |

---

## Pane: Advanced

**Hero card:** "Advanced — Power-user controls. Edit with care." Icon: `wrench.and.screwdriver.fill` on dark gray.

### Section: Quick Terminal [P1]

All `quick-terminal-*` keys: position, size, screen, autohide, animation duration, space behavior, keyboard interactivity.

### Section: Custom shaders [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Shaders | `custom-shader` | path list | Disclosure → list editor (drag-drop GLSL/Metal files) | new |
| Animate when idle | `custom-shader-animation` | enum | Picker: Always / On change / Never | live |

### Section: Performance [P2]

- `async-backend` — Picker
- `image-storage-limit` — Stepper in MB
- `undo-timeout` — Stepper in seconds
- `scrollback-limit` — (duplicates Clipboard & Mouse — show only here? or there? — decide.)

### Section: Splits [P1]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Inherit working directory | `split-inherit-working-directory` | bool | Toggle | new |
| Preserve zoom across splits | `split-preserve-zoom` | bool | Toggle | live |
| Tab inherit working directory | `tab-inherit-working-directory` | bool | Toggle | new |

### Section: Links [P2]

- `link` — disclosure to a regex/style list editor
- `link-url` — Toggle (URL detection)
- `link-previews` — Toggle

### Section: Profile (config file) management [P0 — see Phase 6]

| Row | Key | Type | Control | Reload |
|---|---|---|---|---|
| Active config file | (derived) | path | Display | — |
| Override location | (UI choice) | path | File picker | restart |
| Profile presets | (`config-file = ?name`) | list | Disclosure → preset manager | live |
| Open in text editor | (action) | button | Button → opens config in `$EDITOR` | — |

---

## Pane: About

App metadata, not Ghostty config. Uses the standard `Form { Section { ... } }.formStyle(.grouped)` shell for visual consistency with other panes, with a centered hero section at the top.

### Section: Hero [P0]

Centered layout, no header:

- **App logo** — render `Image("Logo")` from `Assets.xcassets/Logo.imageset` (sourced from `assets/branding/logo-source.png`). 96×96pt, 14pt continuous-corner rounded rect (matches the macOS app-icon squircle for that size — but since the logo *is* the app icon, this clips the same way the Dock renders it).
- Below: app name in `.title`, then version (e.g. "1.0.0 (Build 42)") in `.callout` secondary, then Ghostty installed version (read from `ghostty --version`) in `.subheadline` tertiary.

### Section: Ghostty Help (per [Principle 6](./03-ux-principles.md#principle-6-connect-to-live-help-from-the-app)) [P0]

Each row is a `Link("...", destination: URL)`. Pick up macOS blue-link styling automatically.

- Ghostty website → https://ghostty.org
- Configuration docs → https://ghostty.org/docs/config
- Full option reference → https://ghostty.org/docs/config/reference
- Keybindings reference → https://ghostty.org/docs/config/keybind
- Keybind actions reference → https://ghostty.org/docs/config/keybind/reference
- Trigger sequences (chords) → https://ghostty.org/docs/config/keybind/sequence
- Themes browser (community) → https://github.com/ghostty-org/ghostty/tree/main/src/config/themes
- Ghostty source code → https://github.com/ghostty-org/ghostty
- Report a Ghostty issue → https://github.com/ghostty-org/ghostty/issues

### Section: Configurator [P0]

- Configurator source → (your GitHub URL)
- Report a configurator issue → (your GitHub issues URL)
- Privacy policy → (TBD — short doc covering "no telemetry collected" or whatever ends up true)

### Section: Credits & License [P1]

- Built by [Goutham Ganesan](https://goutham.dev) (or your link)
- MIT License — text shown via disclosure or sheet
- Acknowledgements: SwiftUI, AppKit, Ghostty by Mitchell Hashimoto

---

## What's omitted (HIDE)

The following keys are deliberately not exposed in the GUI:

| Key(s) | Why hidden |
|---|---|
| All `gtk-*` (11 keys) | Linux-only, not relevant on macOS |
| All `linux-*` (4 keys) | Linux-only |
| `x11-instance-name`, `class` | X11/Linux window-manager hints |
| `gtk-titlebar*`, `gtk-toolbar-style`, `gtk-tabs-location`, `gtk-wide-tabs`, `gtk-custom-css`, `gtk-quick-terminal-*`, `gtk-single-instance`, `gtk-opengl-debug` | GTK-specific |
| `enquiry-response`, `vt-kam-allowed`, `osc-color-report-format`, `title-report` | Low-level terminal protocol; tiny audience |
| `config-default-files` | Used by Ghostty itself; user shouldn't touch |
| `language` | Set by macOS system locale; Ghostty respects it |
| `abnormal-command-exit-runtime` | Niche; expose only in Advanced if asked |
| `chained-actions` | Defaults to true; rarely changed |
| `progress-style`, `desktop-notifications` | Behavior overlap with `notify-on-command-finish` |
| `title` | Usually set by shell; manual override is niche |
| `input` | Underspecified in docs; defer until clearer |

Total hidden: ~30 of 188 keys. Surface area shown in GUI: ~158 keys. Of those, P0 covers ~70 keys; the rest are P1/P2 disclosed under "Advanced…".

---

## Priority summary (v1 ship surface)

**P0 — must ship in v1 (~70 keys across 6 panes):**
- Appearance: Theme, Colors, Transparency & Blur
- Window: Titlebar, Padding
- Font: Family, Size & Weight
- Cursor: Style
- Shell: Default command, Integration
- Clipboard & Mouse: Selection, Paste protection, Permissions
- General: Startup, Updates, Notifications
- Keyboard: at minimum view-only listing (editor is P0 but design-heavy)

**P1 — v1 polish or v1.1 (~50 keys):**
- Appearance: Background Image
- Window: Initial size & position, Fullscreen
- Font: Features
- Cursor: Behavior
- Shell: Behavior
- Clipboard & Mouse: Mouse, Scrollback
- General: Bell, macOS, Dock icon
- Advanced: Quick Terminal, Custom shaders, Splits

**P2 — defer to v2 (~30 keys):**
- Appearance: Advanced color
- Window: Color space
- Font: Codepoint mapping, Cell metrics
- Keyboard: Key remapping, Key tables
- Advanced: Performance, Links

**HIDE — never in GUI (~30 keys):**
- All GTK/Linux/X11 keys, low-level protocol toggles, deprecated/internal keys.

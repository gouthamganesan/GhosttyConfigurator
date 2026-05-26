# Ghostty Configuration — Reference for Building a Native macOS Configurator

**Scope.** Distilled from Ghostty's own docs (HTML mirrors saved in `docs/source/`) and the official site:

- Overview: https://ghostty.org/docs/config
- Full option reference: https://ghostty.org/docs/config/reference
- Keybind overview: https://ghostty.org/docs/config/keybind
- Trigger sequences: https://ghostty.org/docs/config/keybind/sequence
- Action reference: https://ghostty.org/docs/config/keybind/reference
- Source of truth (Zig): https://github.com/ghostty-org/ghostty/blob/main/src/config/Config.zig
- Key code list: https://github.com/ghostty-org/ghostty/blob/main/src/input/key.zig

**Ghostty version reference.** The docs reflect ~v1.2.x — 1.2.3 introduced the new `config.ghostty` filename, several entries are marked `Available since: 1.2.0` / `1.3.0`. Treat the inventory as a moving target; the schema can churn between minor releases.

---

## 1. Config file basics

### 1.1 File location (macOS) — load order

Ghostty looks for the config file at these paths, **in order**, merging later files over earlier ones (later wins on conflict):

1. `$XDG_CONFIG_HOME/ghostty/config.ghostty`
2. `$XDG_CONFIG_HOME/ghostty/config` (legacy name, pre-1.2.3)
3. `$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty`
4. `$HOME/Library/Application Support/com.mitchellh.ghostty/config` (legacy)

`$XDG_CONFIG_HOME` defaults to `$HOME/.config`. **All macOS-specific paths are loaded after all XDG paths** — so a value in the macOS path overrides the XDG one. No config file at all is fine; defaults are sensible.

**Practical implication for the configurator:** you must pick *one* canonical write location and stick with it, but you must *read* all of them and visually surface where each key actually came from (or warn when conflicting values appear across files). The canonical macOS path most users expect is `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`, but XDG-purists will hate that — make it a setting.

### 1.2 File format

It's a **custom, intentionally simplistic `key = value` text format**. Not TOML, not INI (despite the docs syntax-highlighting it as INI). Rules:

- **Comments**: `# this is a comment` — `#` must be at the start of a line. **No inline comments.**
- **Blank lines** are ignored.
- **Whitespace** around `=` doesn't matter.
- **Keys** are case-sensitive and always lowercase in the official surface.
- **Values** may be quoted (`"JetBrains Mono"`) or unquoted (`JetBrains Mono`). Quotes only matter when the leading char would otherwise be special (e.g. `?` for `config-file`).
- **No sections / no nesting / no arrays.** Multi-value options are expressed by **repeating the key**:
  ```
  font-family = JetBrains Mono
  font-family = Apple Color Emoji
  keybind = ctrl+z=close_surface
  keybind = ctrl+d=new_split:right
  ```
- **Empty value resets to default**: `font-family =` (trailing equals, no value) is a documented, valid way to clear a previous value.
- **Every key is also a CLI flag**: `ghostty --font-family="JetBrains Mono" --background=282c34`. Strong hint about the parser's mental model — a key is a flag whose default-source is the config file.
- **Splitting across files** via `config-file = path`:
  - Processed at *end* of current file (keys after the `config-file =` line do NOT override included file values).
  - Relative paths are relative to the file containing the `config-file` directive.
  - `config-file = ?optional/path` — leading `?` means "load if present, ignore if not". Escape literal `?` filenames by quoting.
  - Cycle detection built-in (warns).

### 1.3 Reloading

- **macOS default keybind**: `cmd+shift+,` (Linux: `ctrl+shift+,`).
- Bound to the `reload_config` action — fully rebindable.
- **Hot-reload is partial.** The docs are explicit: "Some configuration options cannot be reloaded at runtime; others may only apply to newly created terminals." Each option's reference entry documents its reload semantics. Notable callouts:
  - `background-opacity` on macOS — "changing this configuration requires restarting Ghostty completely."
  - `macos-titlebar-style` — "Changing this option at runtime only applies to new windows."
  - `font-size` — affects existing terminals *unless* the user has manually zoomed; manually-zoomed surfaces keep their zoom.
  - `macos-titlebar-proxy-icon` — only updates after the working directory changes again.
- **No system-wide file watcher** — the user (or the configurator) must trigger reload explicitly.

### 1.4 CLI flags for introspection

These are the configurator's best friends. All are `ghostty +<subcommand>`:

| Command | What it gives you |
|---|---|
| `ghostty +show-config` | User's *effective* config (resolved across all files + CLI). |
| `ghostty +show-config --default` | The full *default* config. |
| `ghostty +show-config --default --docs` | Full default config **with inline doc comments** — the closest thing Ghostty has to a schema export. Pipe through a pager. |
| `ghostty +list-keybinds` | Effective keybinds. |
| `ghostty +list-keybinds --default` | All default keybinds. |
| `ghostty +list-actions` | All keybind actions (referenced from the `keybind` option page). |
| `ghostty +list-themes` | All built-in + user themes. |
| `ghostty +list-fonts` (referenced from `font-family` docs) | All discoverable fonts. |

**Offline docs that ship with the app:**

- HTML + Markdown reference: `Ghostty.app/Contents/Resources/ghostty/docs/`
- Man pages: `Ghostty.app/Contents/Resources/ghostty/share/man/`
- Built-in themes: `Ghostty.app/Contents/Resources/ghostty/themes/`

### 1.5 Is there a JSON / machine schema?

**No.** Ghostty deliberately exposes no JSON-schema export. Closest substitutes, descending robustness:

1. `ghostty +show-config --default --docs` — text format, parseable, but you write a parser for the comment-block-then-key pattern.
2. Compiled-in docs at `Ghostty.app/Contents/Resources/ghostty/docs/config.md` (same source).
3. `src/config/Config.zig` — the Zig struct is canonical. Field names map 1:1 to keys (with `_` ↔ `-` munging); types and defaults are declared inline; doc comments above each field are descriptions; Zig comptime tags encode enum variants. Parsing Zig is annoying but tractable.
4. `+list-actions` and `+list-themes` for dynamic enums.

**Recommendation**: bootstrap a JSON schema by parsing `+show-config --default --docs` once at install time and per Ghostty upgrade, cache it, verify against `+list-actions` / `+list-themes`. Don't hand-curate — it'll drift.

---

## 2. Categorical inventory of config keys

The reference page is **flat** — Ghostty does not officially group options. I extracted **204 jumplink IDs** (a handful are page anchors; ~188 are real keys). Categories below are *my* grouping based on key prefix, intended for a System-Settings-style UI.

Counts per category header indicate keys-by-prefix; "Detailed: N" shows how many appear in the table. Remaining keys per category can be enumerated programmatically from the IDs list in Appendix A.

For type/default columns: where the docs don't explicitly state the default (common — Ghostty embeds defaults in prose), I infer from the Zig source via prior knowledge and mark uncertain entries with `?`. **The configurator should verify all defaults against `+show-config --default` at runtime.** Reload column: `live` = effective immediately, `new` = applies only to newly created surfaces/windows, `restart` = requires full Ghostty restart, `partial` = mixed.

### 2.1 Font (Detailed: 11 / Total ~22)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `font-family` | string (repeatable) | JetBrains Mono (embedded) | — | Primary font; repeat for fallback order. Generate list with `ghostty +list-fonts`. | live |
| `font-family-bold` | string (repeatable) | (auto) | — | Bold-style font override. | live |
| `font-family-italic` | string (repeatable) | (auto) | — | Italic-style font override. | live |
| `font-family-bold-italic` | string (repeatable) | (auto) | — | Bold-italic font override. | live |
| `font-size` | float | 13 (macOS), 12 (Linux) | — | Point size; non-integer allowed for half-pixel sizes. | live (except manually-zoomed terms) |
| `font-style` | string\|`default`\|`false` | `default` | `default`,`false`,name | "Regular" face selection. | live |
| `font-feature` | string (repeatable) | — | OpenType feature tags | E.g. `+liga`, `-calt`. Empty by default; `font-feature =` resets. | live |
| `font-variation` | string (repeatable) | — | axis=value pairs | Variable-font axis overrides. | live |
| `font-synthetic-style` | flag list | `bold,italic,bold-italic` | flag set | Allow synthesized bold/italic when real face is missing. | live |
| `font-thicken` | bool | `false` (macOS only) | true/false | Slightly thicker glyphs on macOS. | live |
| `font-codepoint-map` | string (repeatable) | — | `U+XXXX-U+YYYY=font` | Force specific Unicode ranges to a specific font (huge for emoji/CJK control). | live |

Other font-* keys not detailed: `font-style-bold`, `font-style-italic`, `font-style-bold-italic`, `font-variation-bold`, `font-variation-italic`, `font-variation-bold-italic`, `font-thicken-strength`, `font-shaping-break`, `freetype-load-flags`, `grapheme-width-method`, plus the 11 `adjust-*` keys (§2.10).

### 2.2 Colors & Theme (Detailed: 12 / Total ~18)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `theme` | string | — | built-in theme names, paths, or `light:X,dark:Y` | Single name OR `light:NameA,dark:NameB` split. Path = absolute, name = looks in `~/.config/ghostty/themes/` then bundled. Themes are config snippets. List with `ghostty +list-themes`. | live |
| `background` | color | `282c34` | hex `#RRGGBB`/`RRGGBB` or X11 name | Window background. | live |
| `foreground` | color | `ffffff` | same | Default text color. | live |
| `palette` | indexed color (repeatable) | xterm 256-color | `N=#RRGGBB` (0–255) | ANSI 0–15 most important; 16–255 auto-generated if `palette-generate=true`. | live |
| `palette-generate` | bool | `false` | true/false | Auto-derive 16–255 from base 16. Since 1.3.0. | live |
| `selection-foreground` | color | (auto) | — | — | live |
| `selection-background` | color | (auto) | — | — | live |
| `cursor-color` | color | (auto) | — | — | live |
| `cursor-text` | color\|`cell-foreground`\|`cell-background` | (auto) | — | Color of text *under* cursor. Special keywords since 1.2.0. | live |
| `bold-color` | color\|`bright`\|`cell-foreground` | (none) | — | Tint bold text. | live |
| `minimum-contrast` | float | `1.0` | 1.0–21.0 | Forces APCA-style contrast floor between fg/bg. | live |
| `unfocused-split-opacity` | float | `0.7` | 0–1 | Dim unfocused splits. | live |

Other color/theme keys: `unfocused-split-fill`, `split-divider-color`, `search-background`, `search-foreground`, `search-selected-background`, `search-selected-foreground`, `faint-opacity`, `osc-color-report-format`.

### 2.3 Cursor (Detailed: 6 / Total 6)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `cursor-style` | enum | `block` | `block`,`bar`,`underline`,`block_hollow` | Default style (programs can override via `CSI q`). | live |
| `cursor-style-blink` | tri-state | `null` (blinks, respects DEC mode 12) | (blank), `true`, `false` | Set explicitly to override DECSCUSR-respect behavior. | live |
| `cursor-color` | color | (auto) | — | — | live |
| `cursor-text` | color or `cell-*` | (auto) | — | See §2.2. | live |
| `cursor-opacity` | float | `1.0` | 0–1 | — | live |
| `cursor-click-to-move` | bool | `false` | true/false | Click-to-move-cursor at prompts (needs shell integration OSC 133). | live |

### 2.4 Window (Detailed: 12 / Total ~22)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `window-decoration` | enum\|bool | `auto` | `none`,`auto`,`client`,`server`, `true`(=auto), `false`(=none) | OS decorations preference. `true`/`false` accepted for back-compat. | new |
| `window-padding-x` | int or `LEFT,RIGHT` | `2` | non-negative | Horizontal padding in pixels (or `LEFT,RIGHT`). | live |
| `window-padding-y` | int or `TOP,BOTTOM` | `2` | non-negative | Vertical padding. | live |
| `window-padding-balance` | bool | `false` | true/false | Add extra padding so cells are equally spaced from edges. | live |
| `window-padding-color` | enum | `background` | `background`,`extend`,`extend-always` | Painted color in the padding region. | live |
| `window-theme` | enum | `auto` | `auto`,`system`,`light`,`dark`,`ghostty` | Titlebar/chrome theme. `ghostty` = use config bg/fg (Linux only). | new |
| `window-height` / `window-width` | int (cells) | `0` (= OS chooses) | non-negative | Initial size in cells (0 = no override). | new |
| `window-save-state` | enum | `default` | `default`,`never`,`always` | macOS state restoration. | new |
| `window-new-tab-position` | enum | `current` | `current`,`end` | Where a new tab inserts. | live |
| `window-title-font-family` | string | (system) | font names | Font for tab/title bar text (since 1.0 macOS). | live |
| `window-colorspace` | enum | `srgb` | `srgb`,`display-p3` | Color space for rendering. | restart |
| `window-vsync` | bool | (platform-default) | true/false | VSync for rendering. | restart |

Other window-* keys: `window-position-x/y`, `window-step-resize`, `window-inherit-working-directory`, `window-inherit-font-size`, `window-subtitle` (GTK), `window-show-tab-bar`, `window-titlebar-background`, `window-titlebar-foreground`, `maximize`, `fullscreen`, `initial-window`, `resize-overlay`, `resize-overlay-position`, `resize-overlay-duration`, `class`, `x11-instance-name`.

### 2.5 macOS-specific (Detailed: 10 / Total 16)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `macos-titlebar-style` | enum | `transparent` | `native`,`transparent`,`tabs`,`hidden` | Heart of the macOS look-and-feel. `tabs` integrates tab bar into titlebar (macOS 14+ best). `hidden` keeps frame but removes titlebar (option+click on frame to drag). | new |
| `macos-titlebar-proxy-icon` | enum | `visible` | `visible`,`hidden` | Folder-icon next to title (native style only). Live but only re-evaluates on `cd`. | live (partial) |
| `macos-option-as-alt` | enum\|bool | unset (depends on layout — `true` for US Standard / US International, else `false`) | `true`,`false`,`left`,`right`,unset | Treat Option as Alt for terminal apps (breaks `option+e=é` Unicode if true). | live |
| `macos-non-native-fullscreen` | enum | `false` | `false`,`true`,`visible-menu`,`padded-notch` | Fullscreen mode. Non-native = no animation, no separate Space. | new |
| `macos-window-shadow` | bool | `true` | true/false | — | new |
| `macos-window-buttons` | enum | `visible` | `visible`,`hidden` | Traffic light visibility. | new |
| `macos-auto-secure-input` | bool | `true` | true/false | Auto-enable secure keyboard input at password prompts. | live |
| `macos-secure-input-indication` | bool | `true` | true/false | Show secure-input lock icon in titlebar. | live |
| `macos-icon` | enum | `official` | `official`,`blueprint`,`chalkboard`,`microchip`,`glass`,`holographic`,`paper`,`retro`,`xray`,`custom-style` | Dock/app icon variant — Ghostty ships multiple icons; `custom-style` lets you mix ghost/screen/frame colors. | restart |
| `macos-icon-frame` | enum | `aluminum` | `aluminum`,`beige`,`plastic`,`chrome` | Frame style when `macos-icon = custom-style`. | restart |

Other macos-* keys: `macos-icon-ghost-color`, `macos-icon-screen-color`, `macos-applescript`, `macos-shortcuts`, `macos-hidden`, `macos-custom-icon`, `macos-dock-drop-behavior`.

### 2.6 Background image, blur, opacity (Detailed: 6)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `background-opacity` | float | `1.0` | 0–1 (clamped) | Window bg opacity. macOS: requires restart; disabled in native fullscreen. | restart (macOS) |
| `background-opacity-cells` | bool | `false` | true/false | Apply opacity to cells with explicit bg too (affects Neovim/tmux bg painting). Since 1.2.0. | live |
| `background-blur` | int\|bool\|enum | `false` (0) | nonneg int, `true`(=20), `false`(=0), `macos-glass-regular`, `macos-glass-clear` (macOS 26+) | Blur intensity behind transparent bg. macOS native Liquid-Glass values are new. | new |
| `background-image` | path | — | absolute path | Image painted behind cells. | live |
| `background-image-opacity` / `-position` / `-fit` / `-repeat` | float / enum / enum / bool | sane defaults | various | Composition controls for background image. | live |
| `alpha-blending` | enum | `native` | `native`,`linear`,`linear-corrected` | Compositing model — `linear-corrected` is most "correct" but breaks some legacy expectations. | restart |

### 2.7 Scrollback & search (Detailed: 4 / Total ~6)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `scrollback-limit` | size | `10000000` (10MB) | bytes (suffixes ok) | Per-surface scrollback buffer cap. | new |
| `scrollbar` | enum | (platform) | — | Scrollbar visibility/style. | new |
| `scroll-to-bottom` | flag list | `keystroke,output` | comma flags | When to auto-scroll. | live |
| `mouse-scroll-multiplier` | float | `3.0` discrete / `1.0` precision | — | Wheel/trackpad scroll multiplier. | live |

### 2.8 Selection, mouse, clipboard (Detailed: 9 / Total ~13)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `copy-on-select` | enum\|bool | `true` | `true`,`false`,`clipboard` | macOS default uses selection clipboard pattern. | live |
| `clipboard-read` | enum | `ask` | `allow`,`deny`,`ask` | Permission for OSC 52 read. | live |
| `clipboard-write` | enum | `allow` | `allow`,`deny`,`ask` | Permission for OSC 52 write. | live |
| `clipboard-paste-protection` | bool | `true` | true/false | Warn on dangerous (control-char-containing) paste. | live |
| `clipboard-paste-bracketed-safe` | bool | `true` | true/false | Trust bracketed-paste from terminal program. | live |
| `clipboard-trim-trailing-spaces` | bool | `true` | true/false | — | live |
| `selection-clear-on-typing` | bool | `true` | true/false | — | live |
| `selection-clear-on-copy` | bool | `false` | true/false | — | live |
| `selection-word-chars` | string | (built-in set) | chars | Characters considered part of a "word" for double-click. | live |

Other mouse/clipboard: `mouse-hide-while-typing`, `mouse-reporting`, `mouse-shift-capture`, `focus-follows-mouse`, `right-click-action`, `click-repeat-interval`, `clipboard-codepoint-map`.

### 2.9 Bell, notifications, command tracking (Detailed: 5)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `bell-features` | flag list | `attention,title` | `system`,`audio`,`attention`,`title`,`border` (with `no-` prefix) | What a terminal bell triggers. Audio needs `bell-audio-path`. | live |
| `bell-audio-path` | path | — | abs path to wav/etc | Audio file for the bell. | live |
| `bell-audio-volume` | float | `0.5` | 0–1 | — | live |
| `app-notifications` | flag list | `clipboard-copy` and more | `clipboard-copy`,`no-clipboard-copy`,`config-reload`,`crash` | Which UI notifications to show. | live |
| `notify-on-command-finish` | enum | `false` | `false`,`always`,`unfocused` | macOS notifications when long commands finish. | live |

Other: `notify-on-command-finish-after`, `notify-on-command-finish-action`, `desktop-notifications`, `progress-style`, `abnormal-command-exit-runtime`.

### 2.10 Cell metrics / "adjust" tuning (Detailed: 0 / Total 13)

All of: `adjust-cell-width`, `adjust-cell-height`, `adjust-font-baseline`, `adjust-underline-position`, `adjust-underline-thickness`, `adjust-strikethrough-position`, `adjust-strikethrough-thickness`, `adjust-overline-position`, `adjust-overline-thickness`, `adjust-cursor-thickness`, `adjust-cursor-height`, `adjust-box-thickness`, `adjust-icon-height`. All accept px value, percentage, or empty (auto). Live reload.

Power-user surface. In the configurator, group these behind an "Advanced — Font Metrics" disclosure with a live preview pane.

### 2.11 Shell integration (Detailed: 2 / Total 2)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `shell-integration` | enum | `detect` | `none`,`detect`,`bash`,`zsh`,`fish`,`elvish`,`nushell` | Whether/how to auto-inject the integration shims. `detect` = sniff from `$SHELL`. | new |
| `shell-integration-features` | flag list | `cursor,sudo,title` | `cursor`,`sudo`,`title`,`ssh-env`,`ssh-terminfo`, plus `no-` variants, plus `true`/`false` for all | Granular toggle of integration sub-features. | new |

### 2.12 Keybindings (Detailed: 5 — but this is the big one; see §4)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `keybind` | binding (repeatable) | many defaults — see `+list-keybinds --default` | `trigger=action` | See §4 for the full grammar. **Duplicate triggers overwrite earlier values.** | live |
| `key-remap` | mapping (repeatable) | — | `physical:key=key` | Remap one physical key to behave like another. | live |
| `key-tables` | nested keybind container | — | — | Define a named key-table that other keybinds can switch into (e.g. tmux-style prefix modes). | live |
| `input` | macOS-only setting | — | — | Input-related quirks. | live |
| `chained-actions` | bool | `true` | true/false | Allow chained actions in keybinds. | live |

### 2.13 Quick Terminal (macOS-specific, Detailed: 0 / Total 7)

Drop-down-terminal feature: `quick-terminal-position` (`top`,`bottom`,`left`,`right`,`center`), `quick-terminal-size`, `quick-terminal-screen` (`main`,`mouse`,`macos-menu-bar`), `quick-terminal-autohide`, `quick-terminal-animation-duration`, `quick-terminal-space-behavior`, `quick-terminal-keyboard-interactivity`. All require Ghostty restart or new quick-terminal invocation.

### 2.14 GTK / Linux-specific (Detailed: 0 / Total 11)

Out of scope for a macOS configurator. All `gtk-*` and `linux-*` keys. The configurator should detect platform and hide these (or expose under a "Linux portability" advanced toggle for users with mixed setups).

### 2.15 Misc / Advanced (Detailed: 12+)

| Key | Type | Default | Enum | Description | Reload |
|---|---|---|---|---|---|
| `command` | string | (`$SHELL` or login shell) | — | Override the shell. | new |
| `initial-command` | string | — | — | Command to run *once* on first surface only. | new |
| `working-directory` | string\|enum | `inherit` | `inherit`,`home`,path | New surface starting cwd. | new |
| `env` | KEY=VAL (repeatable) | — | — | Extra env vars for child processes. | new |
| `term` | string | `xterm-ghostty` | — | `$TERM` value. Don't change unless you know why. | new |
| `confirm-close-surface` | enum | `always` | `always`,`false`,`true`,`always-only-non-prompt` | Confirmation prompt on tab/window close. Shell integration + OSC 133 lets it skip the prompt at a clean prompt. | live |
| `quit-after-last-window-closed` | bool | `false` (macOS, Mac-style) | true/false | — | live |
| `custom-shader` | path (repeatable) | — | abs path to GLSL/Metal | Post-processing pixel shaders (à la ShaderToy). Repeat for a pipeline. Massive aesthetic surface. | new |
| `custom-shader-animation` | enum | `true` | `true`,`false`,`always` | Drive shader's `iTime` even when terminal is idle. | live |
| `link` / `link-url` / `link-previews` | various | — | — | URL detection and click behavior. | live |
| `auto-update` / `auto-update-channel` | enum | (platform) | — | Sparkle-based macOS auto-update behavior. | live |
| `image-storage-limit` | size | `320 MB` | bytes | Cap for Kitty image protocol storage. | live |
| `undo-timeout` | duration | `30 seconds` | — | How long undo (for closed tabs etc.) holds history. | live |

Other keys not above: `config-file`, `config-default-files`, `language`, `enquiry-response`, `title`, `title-report`, `tab-inherit-working-directory`, `split-inherit-working-directory`, `split-preserve-zoom`, `command-palette-entry`, `vt-kam-allowed`, `wait-after-command`, `async-backend`.

---

## 3. Themes

### 3.1 How `theme = ...` resolves

Three forms:

```
theme = Catppuccin Mocha                              # built-in OR user theme name
theme = /Users/me/.config/ghostty/my-theme            # absolute path
theme = light:Rose Pine Dawn,dark:Rose Pine           # macOS auto light/dark switch
```

For names (no path), search order:

1. `~/.config/ghostty/themes/<name>` (XDG)
2. `Ghostty.app/Contents/Resources/ghostty/themes/<name>` (bundled)

**Case-sensitive on case-sensitive filesystems.** Name **cannot contain path separators**.

### 3.2 Theme file format

A theme file is **just another Ghostty config file** — same `key = value` syntax. By convention themes set `background`, `foreground`, `palette = 0=…` through `palette = 15=…`, sometimes `cursor-color`, `selection-*`. **Themes may set any option**, so they're not pure presentation — security note: don't load untrusted theme files; bundled ones are audited.

Themes **cannot set** `theme` or `config-file` (silently ignored). Any colors set in the user config *after* loading a theme override the theme.

### 3.3 Listing & adding

- `ghostty +list-themes` — prints all known themes (bundled + user).
- Add custom: drop a file in `~/.config/ghostty/themes/<MyName>` then `theme = MyName`.
- Ghostty ships **hundreds of themes** (the iTerm2 color schemes / base16 / Catppuccin / Rose Pine / Solarized / Tokyo Night / Nord / Gruvbox / etc. universe). Browse online: https://github.com/ghostty-org/ghostty/tree/main/src/config/themes — ~300+ files at HEAD.

### 3.4 light:/dark: split caveats

- Whitespace trimmed; order of `light:` vs `dark:` doesn't matter; **both must be specified**.
- Switching follows OS appearance.
- Known bug: macOS titlebar-tabs style doesn't refresh on theme switch.

### 3.5 Implications for the configurator

This is **the** killer feature for a GUI: a live theme browser with a real preview is high-leverage. Suggested model:

- Enumerate via `+list-themes`.
- Read each theme file directly (same parser as user config) to extract palette → render a swatch grid + a fake terminal preview.
- Support drag-drop of `.tic` / `.colorscheme` files from iTerm2 / Alacritty / Windows Terminal with a conversion step.
- The light/dark pair UI should be a single "auto-switch" toggle that exposes two pickers — most users don't know this exists.

---

## 4. Keybindings grammar

Format: `keybind = TRIGGER = ACTION`. RHS is `action` or `action:param`.

### 4.1 Trigger grammar

```
TRIGGER       := PREFIX* KEY_PART ( ">" KEY_PART )*
PREFIX        := "all:" | "global:" | "unconsumed:" | "performable:"
KEY_PART      := MODIFIER ("+" MODIFIER)* "+" KEY  |  KEY
MODIFIER      := "shift" | "ctrl" | "control" | "alt" | "opt" | "option" | "super" | "cmd" | "command"
KEY           := keyname | unicode_codepoint | "KeyA".."Numpad0"... (W3C codes, case-sensitive) | "key_a" (lowercase alias) | "f1".."f24" | "catch_all"
```

- **Modifiers** are unordered (`shift+a+ctrl` legal but ugly). Same modifier cannot repeat.
- **At most one non-modifier key** per part (`ctrl+a+b` invalid).
- Three modes of specifying the key:
  1. **Logical (Unicode)**: `a` matches whatever produces `a` on the current keyboard layout. **Case-folded** for comparison — `ctrl+A` matches `ctrl+a` press. Modifier-matching is *strict* on the unmodified codepoint — `ctrl+_` on US is impossible because `_` is `shift+-`.
  2. **Physical (W3C codes)**: `KeyA`, `Digit1`, `Numpad5`, `key_a` (snake-case alias). Case-sensitive. Matches a physical key regardless of layout.
  3. **Special keys**: `up`, `down`, `enter`, `escape`, `f1`–`f24`, `home`, `end`, `pgup`, `pgdn`, `tab`, `space`, etc. (full list in `src/input/key.zig`).
- **Priority**: physical keys win over Unicode logical keys when both bound.
- **`catch_all`**: matches anything not otherwise bound, optionally with modifiers (`ctrl+catch_all`). Fallback chain: `MOD+catch_all` → `catch_all` (modifierless).
- **No `fn` / `globe` modifier support** — OS limitation.

### 4.2 Trigger prefixes

| Prefix | Meaning |
|---|---|
| `all:` | Apply to *every* terminal surface, not just the focused one. No effect on already-global actions like `quit`. |
| `global:` | **macOS only.** Apply system-wide even when Ghostty isn't focused. Requires Accessibility permissions. Implies `all:`. |
| `unconsumed:` | The encoded keypress is *also* sent to the running program. Default is to consume. Useful for `unconsumed:ctrl+a=reload_config`. **Ignored** for `global:`/`all:` (always consume). |
| `performable:` | Consume input *only if* the action can be performed (e.g. `copy_to_clipboard` only if there's a selection). For sequences: resets the sequence if not performable. **Note: performable keybinds do not appear as menu shortcuts** in the macOS menu bar. |

Prefixes can stack: `global:unconsumed:ctrl+a=reload_config`.

**Critical UX rule for the configurator**: triggers are not unique per prefix combination. Setting `ctrl+a=X` then `global:ctrl+a=Y` results in `Y` only — the later one wins, with the `global:` prefix carried. The configurator must treat a trigger as a *single* slot keyed by `(prefix-set, key+modifiers)` collapsed back to the key+modifiers.

### 4.3 Trigger sequences (chords / leader keys)

```
keybind = ctrl+a>n=new_window
keybind = ctrl+a>t=new_tab
keybind = ctrl+a>ctrl+a=text:foo   # press ctrl+a twice to emit "foo"
```

Sequence rules:

- **No timeout.** Ghostty waits indefinitely for the next key. Only escape: bind prefix-to-itself to literal output, or press an unbound key.
- **Sequences shadow shorter bindings**: binding `ctrl+a>n` makes any direct `ctrl+a` action stop working.
- **Inverse**: later binding `ctrl+a=something` directly will **unbind all `ctrl+a>*` sequences**.
- **No nesting cap** — `ctrl+a>b>c>d=foo` is legal.
- **Cannot combine with `global:` or `all:`** prefixes.
- On the CLI: must quote because `>` is a shell metachar.

### 4.4 Action vocabulary

`ghostty +list-actions` is authoritative. The reference page enumerates 80 actions, grouped:

- **Special/control**: `ignore`, `unbind`, `csi:<seq>`, `esc:<seq>`, `text:<str>`, `cursor_key:<dir>`, `reset`, `end_key_sequence`
- **Clipboard**: `copy_to_clipboard`, `paste_from_clipboard`, `paste_from_selection`, `copy_url_to_clipboard`, `copy_title_to_clipboard`
- **Font size**: `increase_font_size`, `decrease_font_size`, `reset_font_size`, `set_font_size:<pt>`
- **Search**: `search`, `search_selection`, `start_search`, `end_search`, `navigate_search:next|previous`
- **Screen / scrolling**: `clear_screen`, `select_all`, `scroll_to_top`, `scroll_to_bottom`, `scroll_to_selection`, `scroll_to_row:<n>`, `scroll_page_up`, `scroll_page_down`, `scroll_page_fractional:<f>`, `scroll_page_lines:<n>`, `adjust_selection:<dir>`, `jump_to_prompt:<n>`
- **Writing to files**: `write_scrollback_file:open|paste|copy`, `write_screen_file:open|paste|copy`, `write_selection_file:open|paste|copy`
- **Tabs/windows**: `new_window`, `new_tab`, `previous_tab`, `next_tab`, `last_tab`, `goto_tab:<n>`, `move_tab:<delta>`, `toggle_tab_overview`, `prompt_surface_title`, `prompt_tab_title`, `set_surface_title:<str>`, `set_tab_title:<str>`
- **Splits**: `new_split:right|down|left|up|auto`, `goto_split:right|down|left|up|previous|next`, `goto_window:previous|next`, `toggle_split_zoom`, `resize_split:<dir>,<px>`, `equalize_splits`
- **Window state**: `reset_window_size`, `toggle_maximize`, `toggle_fullscreen`, `toggle_window_decorations`, `toggle_window_float_on_top`, `toggle_visibility`, `toggle_background_opacity`
- **Mode toggles**: `toggle_readonly`, `toggle_secure_input`, `toggle_mouse_reporting`, `toggle_command_palette`, `toggle_quick_terminal`
- **Config / app**: `open_config`, `reload_config`, `check_for_updates`, `inspector:toggle|show|hide`, `show_gtk_inspector`, `show_on_screen_keyboard`
- **Surface/tab lifecycle**: `close_surface`, `close_tab`, `close_window`, `close_all_windows`
- **History**: `undo`, `redo`

For each action, the reference page documents valid parameters in plain prose (no machine schema). The configurator should mirror this UI as a typeahead with action-specific param fields.

### 4.5 Default keybinds and precedence

- Run `ghostty +list-keybinds --default` to dump them. Macros differ by platform: macOS is `cmd`-heavy, Linux is `ctrl+shift`-heavy.
- **Duplicate triggers overwrite earlier values** — same as any other repeated config key.
- The macOS native menu bar is auto-generated from non-`performable:` keybinds. Setting `performable:` removes the shortcut label from menus.

---

## 5. The existing Ghostty macOS app — native UI surface

Based on public knowledge of recent releases (1.x); verify against the latest build:

**What Ghostty's macOS app currently exposes natively (no third-party UI needed):**

- **Settings window** (`cmd+,`) — but as of 1.2 it's *bare-bones*. Reportedly opens the config file in `$EDITOR`, or shows a near-empty preferences panel. The docs explicitly say (Configuration page note): *"In the future, we plan to also support native GUIs for configuration… Presently, the text-based configuration is the only way to configure Ghostty."*
- **Menu bar** — full menu reflecting current keybinds (Window, Tab, Edit, View, Splits, etc.).
- **Tab management** — native NSTabView when `macos-titlebar-style != tabs`, or custom tab-in-titlebar when `tabs`.
- **Command palette** — `toggle_command_palette` gives a Raycast-style action runner.
- **Inspector window** — `inspector` action (debug surface for cell/font/shader inspection).
- **Quick Terminal** — `toggle_quick_terminal` slides in a configurable drop-down terminal.
- **Auto-update via Sparkle** — `auto-update-channel = tip|stable`.
- **macOS Services menu integration**, secure-input lock icon, working-directory proxy icon in titlebar.

**What's missing — your value-add surface area:**

1. **Anything visual.** No theme picker, no font browser with preview, no color swatches, no opacity/blur slider with live preview. Today, the only way to *know* a theme is "Catppuccin Mocha" is to read the docs or try it.
2. **Keybinding editor.** No GUI for the chord-language. The trigger grammar is dense enough that even power users mistype it.
3. **Validation.** Typo `font-familiy = X` and Ghostty silently keeps the default. A GUI with schema validation catches this.
4. **Profile / preset management.** No concept of "work profile" vs "personal" — users do this manually via `config-file = ?work-config`. A configurator could surface this elegantly.
5. **Discoverability.** With ~200 options and most users only ever setting ~10, a categorized System-Settings-style nav is genuinely useful.
6. **Diff and version migration.** Showing what changed after a Ghostty upgrade ("here are 12 new options in 1.3") would be a quiet superpower.
7. **Provenance.** Ghostty merges XDG + macOS-paths + CLI flags. A GUI that shows "this value of `font-size` is coming from `~/.config/ghostty/config.ghostty:42`" is something the CLI doesn't.
8. **Sharing / publishing.** Export a sanitized config (strip personal paths) for blog posts or to share with teammates.

---

## 6. Existing community config tools

WebSearch was unavailable in this environment — these are the most-cited tools from training data and the Ghostty community's known landscape (as of early 2026):

| Tool | What it does | Notes |
|---|---|---|
| **Ghostty Themes repos** (e.g. `zerebos/ghostty-themes` on GitHub) | Catalog of community themes beyond the bundled set | Just config snippets to drop into `~/.config/ghostty/themes/`. No GUI. |
| GitHub topic `ghostty-config` (https://github.com/topics/ghostty-config) | Many personal dotfile repos | The "search GitHub for public configs" workflow Ghostty's docs themselves recommend (see https://github.com/search?q=path%3Aghostty%2Fconfig&type=code). |
| Mitchell's own dotfiles (https://github.com/mitchellh/nixos-config) | Reference example | Worth reading for taste. |
| `ghosttyconf.com` / similar generator sites | Web-based theme picker / config snippet builder | Generate a config but offer no live preview against your actual Ghostty. Quality varies. |
| Catppuccin / Rose Pine / Tokyo Night for Ghostty (e.g. https://github.com/catppuccin/ghostty) | Theme distributions, single config files | Just produce a theme file. |
| Various utilities at https://github.com/topics/ghostty | Nightly Discord bot, toolboxes, etc. | **None are a config GUI as of 1.2.x.** The space is open. |

**Bottom line.** As of Ghostty 1.2/1.3, there is **no widely-adopted native macOS configurator**. Mitchell has stated a native UI is on the roadmap — both a tailwind (validates the need) and a headwind (you're building something upstream will eventually ship). The arbitrage is **time-to-market + macOS-native polish + features upstream won't prioritize** (theme browsing UX, share/import workflows, profile management, validation lint, provenance display).

---

## 7. Parsing / writing strategy

### 7.1 Format constraints summary

- Line-oriented; `\n`-separated. No multi-line values.
- `#` at column 0 = full-line comment. **No inline comments allowed.**
- Blank lines preserved-as-blank.
- `key = value`; whitespace around `=` is free-form.
- Keys repeat for list-typed options (`font-family`, `keybind`, `palette`, `font-feature`, `font-variation`, `env`, `custom-shader`, `config-file`, etc.).
- `key =` (empty RHS) **resets to default**, semantically distinct from "key absent".
- Values may be `"quoted"` or unquoted; quoting necessary only when first char is special (e.g. `?` for `config-file = "?literal"`).
- `config-file` inclusion is **processed at the *end* of the current file** — keys after a `config-file` directive in the same file still don't override included file values.
- Includes resolve cycles with a warning, not an error.

### 7.2 Strategy comparison

| Strategy | Pros | Cons | Verdict |
|---|---|---|---|
| **(a) Round-trip with custom parser** — preserve comments, blank lines, ordering; surgically edit individual lines | Respects user's hand-authored file; minimal diff; users can keep editing the file by hand | More code; have to handle list-typed keys carefully (a UI "set font-family to X" might mean replace all `font-family =` lines, or append, depending on intent) | **Recommended.** Mirrors how `defaults`, `git config`, `gh config set` all work. Format is simple enough that a few hundred lines of Swift will handle it. |
| **(b) Use a library** | Zero code | **No library exists for this format** — it's bespoke. Closest is INI parsers, which all break on repeat-key semantics, quoting rules, and `config-file` include semantics. | Skip. |
| **(c) Destructive rewrite from canonical state** — internal model → render whole file | Simplest; deterministic | Destroys user comments, ordering, hand-edits, multi-file structure | **Anti-pattern** for a config most users still hand-edit. Only acceptable for a "Reset to GUI's defaults" button. |

### 7.3 Recommended internal model

```
ConfigFile {
  path: URL
  entries: [Entry]    // ordered: preserves comments, blanks, ordering
}
enum Entry {
  case comment(String)
  case blank
  case kv(key: String, value: String, raw: String /* original whitespace */, sourceLine: Int)
  case include(path: String, optional: Bool, sourceLine: Int)
}
```

Editing operations:

- **Set scalar key** → find last matching `kv`, mutate in-place; if absent, append.
- **Set list key (replace all)** → remove all matching `kv`, append new entries.
- **Append to list key** → append new `kv` at end of group, or end of file if no group.
- **Clear / reset to default** → set to `key =` (empty), which mirrors Ghostty's own semantics. Useful when the default might be overridden by an included file.
- **Delete** → drop the line. (Different from reset.)

For the *include graph* across `config-file` directives, resolve at read time but **write only to the root file** unless the user explicitly opens a sub-file in the GUI. Mirror what Xcode does with `.xcconfig` includes.

### 7.4 Quoting rules to implement carefully

- If value contains leading `?` and you want a literal `?`, wrap in double quotes.
- If value contains a `#` at start, would-be-comment. Quote it.
- For paths with spaces (very common on macOS — `Application Support`), prefer quoting always for readability; Ghostty handles unquoted fine.
- For `keybind` values containing `=` after the trigger, no special quoting needed — Ghostty's parser splits on the *first* `=`.

### 7.5 Reload trigger

After write, fire `reload_config` via:

- **macOS**: send a keystroke or AppleScript via NSAppleScript (if `macos-applescript = allow`), or just nudge the user with a button that triggers `osascript` to send `cmd+shift+,` to Ghostty.
- Alternative: kill all Ghostty windows / instruct user to restart. Practical UX: show a "Reload Ghostty" button after every save; for restart-required keys (`background-opacity` macOS, `window-vsync`, `window-colorspace`, `alpha-blending`, `macos-icon*`), pop a stronger "Restart needed" badge.

---

## Appendix A — Full list of option keys (extracted from saved docs)

204 IDs total on the Option Reference page; ~188 are actual config keys. Full alphabetized list:

`abnormal-command-exit-runtime`, `adjust-box-thickness`, `adjust-cell-height`, `adjust-cell-width`, `adjust-cursor-height`, `adjust-cursor-thickness`, `adjust-font-baseline`, `adjust-icon-height`, `adjust-overline-position`, `adjust-overline-thickness`, `adjust-strikethrough-position`, `adjust-strikethrough-thickness`, `adjust-underline-position`, `adjust-underline-thickness`, `alpha-blending`, `app-notifications`, `async-backend`, `auto-update`, `auto-update-channel`, `background`, `background-blur`, `background-image`, `background-image-fit`, `background-image-opacity`, `background-image-position`, `background-image-repeat`, `background-opacity`, `background-opacity-cells`, `bell-audio-path`, `bell-audio-volume`, `bell-features`, `bold-color`, `chained-actions`, `class`, `click-repeat-interval`, `clipboard-codepoint-map`, `clipboard-paste-bracketed-safe`, `clipboard-paste-protection`, `clipboard-read`, `clipboard-trim-trailing-spaces`, `clipboard-write`, `command`, `command-palette-entry`, `config-default-files`, `config-file`, `confirm-close-surface`, `copy-on-select`, `cursor-click-to-move`, `cursor-color`, `cursor-opacity`, `cursor-style`, `cursor-style-blink`, `cursor-text`, `custom-shader`, `custom-shader-animation`, `desktop-notifications`, `enquiry-response`, `env`, `faint-opacity`, `focus-follows-mouse`, `font-codepoint-map`, `font-family`, `font-family-bold`, `font-family-bold-italic`, `font-family-italic`, `font-feature`, `font-shaping-break`, `font-size`, `font-style`, `font-style-bold`, `font-style-bold-italic`, `font-style-italic`, `font-synthetic-style`, `font-thicken`, `font-thicken-strength`, `font-variation`, `font-variation-bold`, `font-variation-bold-italic`, `font-variation-italic`, `foreground`, `freetype-load-flags`, `fullscreen`, `grapheme-width-method`, `gtk-custom-css`, `gtk-opengl-debug`, `gtk-quick-terminal-layer`, `gtk-quick-terminal-namespace`, `gtk-single-instance`, `gtk-tabs-location`, `gtk-titlebar`, `gtk-titlebar-hide-when-maximized`, `gtk-titlebar-style`, `gtk-toolbar-style`, `gtk-wide-tabs`, `image-storage-limit`, `initial-command`, `initial-window`, `input`, `key-remap`, `key-tables`, `keybind`, `language`, `link`, `link-previews`, `link-url`, `linux-cgroup`, `linux-cgroup-hard-fail`, `linux-cgroup-memory-limit`, `linux-cgroup-processes-limit`, `macos-applescript`, `macos-auto-secure-input`, `macos-custom-icon`, `macos-dock-drop-behavior`, `macos-hidden`, `macos-icon`, `macos-icon-frame`, `macos-icon-ghost-color`, `macos-icon-screen-color`, `macos-non-native-fullscreen`, `macos-option-as-alt`, `macos-secure-input-indication`, `macos-shortcuts`, `macos-titlebar-proxy-icon`, `macos-titlebar-style`, `macos-window-buttons`, `macos-window-shadow`, `maximize`, `minimum-contrast`, `mouse-hide-while-typing`, `mouse-reporting`, `mouse-scroll-multiplier`, `mouse-shift-capture`, `notify-on-command-finish`, `notify-on-command-finish-action`, `notify-on-command-finish-after`, `osc-color-report-format`, `palette`, `palette-generate`, `palette-harmonious`, `progress-style`, `quick-terminal-animation-duration`, `quick-terminal-autohide`, `quick-terminal-keyboard-interactivity`, `quick-terminal-position`, `quick-terminal-screen`, `quick-terminal-size`, `quick-terminal-space-behavior`, `quit-after-last-window-closed`, `quit-after-last-window-closed-delay`, `resize-overlay`, `resize-overlay-duration`, `resize-overlay-position`, `right-click-action`, `scroll-to-bottom`, `scrollback-limit`, `scrollbar`, `search-background`, `search-foreground`, `search-selected-background`, `search-selected-foreground`, `selection-background`, `selection-clear-on-copy`, `selection-clear-on-typing`, `selection-foreground`, `selection-word-chars`, `shell-integration`, `shell-integration-features`, `split-divider-color`, `split-inherit-working-directory`, `split-preserve-zoom`, `tab-inherit-working-directory`, `term`, `theme`, `title`, `title-report`, `undo-timeout`, `unfocused-split-fill`, `unfocused-split-opacity`, `vt-kam-allowed`, `wait-after-command`, `window-colorspace`, `window-decoration`, `window-height`, `window-inherit-font-size`, `window-inherit-working-directory`, `window-new-tab-position`, `window-padding-balance`, `window-padding-color`, `window-padding-x`, `window-padding-y`, `window-position-x`, `window-position-y`, `window-save-state`, `window-show-tab-bar`, `window-step-resize`, `window-subtitle`, `window-theme`, `window-title-font-family`, `window-titlebar-background`, `window-titlebar-foreground`, `window-vsync`, `window-width`, `working-directory`, `x11-instance-name`.

## Appendix B — Full list of keybind actions (80 verbs)

`ignore`, `unbind`, `csi`, `esc`, `text`, `cursor_key`, `reset`, `copy_to_clipboard`, `paste_from_clipboard`, `paste_from_selection`, `copy_url_to_clipboard`, `copy_title_to_clipboard`, `increase_font_size`, `decrease_font_size`, `reset_font_size`, `set_font_size`, `search`, `search_selection`, `navigate_search`, `start_search`, `end_search`, `clear_screen`, `select_all`, `scroll_to_top`, `scroll_to_bottom`, `scroll_to_selection`, `scroll_to_row`, `scroll_page_up`, `scroll_page_down`, `scroll_page_fractional`, `scroll_page_lines`, `adjust_selection`, `jump_to_prompt`, `write_scrollback_file`, `write_screen_file`, `write_selection_file`, `new_window`, `new_tab`, `previous_tab`, `next_tab`, `last_tab`, `goto_tab`, `move_tab`, `toggle_tab_overview`, `prompt_surface_title`, `prompt_tab_title`, `set_surface_title`, `set_tab_title`, `new_split`, `goto_split`, `goto_window`, `toggle_split_zoom`, `toggle_readonly`, `resize_split`, `equalize_splits`, `reset_window_size`, `inspector`, `show_gtk_inspector`, `show_on_screen_keyboard`, `open_config`, `reload_config`, `close_surface`, `close_tab`, `close_window`, `close_all_windows`, `toggle_maximize`, `toggle_fullscreen`, `toggle_window_decorations`, `toggle_window_float_on_top`, `toggle_secure_input`, `toggle_mouse_reporting`, `toggle_command_palette`, `toggle_quick_terminal`, `toggle_visibility`, `toggle_background_opacity`, `check_for_updates`, `undo`, `redo`, `end_key_sequence`.

---

*Sources prioritized in this document — local HTML mirrors at `/Users/gouthamjiii/Projects/GhosttyConfigurator/docs/source/` of the upstream pages:*

- `Configuration.html` ← https://ghostty.org/docs/config
- `Option Reference - Configuration.html` ← https://ghostty.org/docs/config/reference
- `Keybindings - Configuration.html` ← https://ghostty.org/docs/config/keybind
- `Trigger Sequences - Keybindings.html` ← https://ghostty.org/docs/config/keybind/sequence
- `Action Reference - Keybindings.html` ← https://ghostty.org/docs/config/keybind/reference
- Zig source: https://github.com/ghostty-org/ghostty/blob/main/src/config/Config.zig and https://github.com/ghostty-org/ghostty/blob/main/src/input/key.zig — ground truth for type/default/enum.

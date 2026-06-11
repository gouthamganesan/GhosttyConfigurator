# Ghostty Configurator

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Status](https://img.shields.io/badge/status-actively%20maintained-brightgreen.svg)](https://github.com/gouthamganesan/GhosttyConfigurator/commits/main)
[![Version](https://img.shields.io/badge/version-0.1.31-blue.svg)](Configs/Common.xcconfig)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

A native macOS GUI for editing [Ghostty](https://ghostty.org)'s config file —
built to be indistinguishable from System Settings, because on Sonoma+ that
look *is* the SwiftUI default and fighting it only takes you further away.

![logo](assets/branding/logo-source.png)

**Status:** actively maintained (v0.1.31). Reads and writes a real Ghostty
config, introspects the live option schema from the installed `ghostty`
binary, and ships a working theme browser, keybind editor, validation lint,
and global search. Not yet a tagged release — see the roadmap below.

## Why this exists

Press `cmd + ,` in most Mac apps and you get a settings window. Press it in
Ghostty and it opens a plain text file in your editor. That's deliberate, not
neglect: Ghostty is built around sensible defaults and a zero-configuration
philosophy, and [the text file is currently the only way to configure
it](https://ghostty.org/docs/config). The docs promise that "in the future, we
plan to also support native GUIs for configuration in line with our native UI
philosophy," and Mitchell Hashimoto has
[said](https://terminaltrove.com/blog/terminal-trove-talks-with-mitchell-hashimoto-ghostty/)
GUI-based configuration is one of the features "missing in the initial 1.0
release but that we know are important." Great terminal core first, settings
UI later. Fair call. But the gap is real today.

### The problem

Configuring Ghostty today means: open the config file, open the reference
docs in a browser, hunt for the right key, learn its exact syntax, type it in
by hand, save, reload, and hope. The failure mode is silent. Ghostty ignores
anything it doesn't recognize: typo `font-familiy` and nothing complains, no
error, no lint. Your setting just doesn't apply and the default quietly
stays. You find out later, when something looks off, and troubleshoot
backwards through the docs.

The nuances stack up:

- **Discovery is half the problem.** 188 options, ~80 keybind actions, ~460
  bundled themes. You can't configure what you don't know exists.
- **Some values have their own grammar.** `theme = light:X,dark:Y`, keybind
  chords and sequences, `font-feature = -calt`. Each is a small language to
  learn before you can use it.
- **Config can span multiple files** via includes, with two valid config
  locations and a merge order. "Which file did this value come from" is a
  genuine question.
- **Theme picking is blind.** Set `theme = name`, reload, look, repeat.
  Nobody does that 460 times; everybody settles.

### Prior art

[ghostty.zerebos.com](https://ghostty.zerebos.com/) is a genuinely nice
web-based configurator, and it was the first thing I tried. Two gaps kept it
from solving the problem: it still assumes you speak the config (plenty of
fields expect raw values and deep option knowledge), and the last mile stays
manual: it generates config text you copy into your file yourself. The risky
step, the one with no validation and silent failures, is exactly the step it
leaves with you. It's a faster keyboard for experts. This app aims to be a
translator for everyone else.

### The answer

A native macOS app that presents every setting in System-Settings-style
panes, explains each field and each possible value with friendly labels
(never raw flags or grammar in the UI; the verbatim Ghostty docs are one
click away), and loads, modifies, and writes the config file directly. No
generated text, no copy-paste step.

What that unlocks beyond "a form that edits a file":

- **Theme browser with live preview.** Browse the bundled themes against
  a real terminal preview instead of editing `theme = ?` blind.
- **Keybind editor.** Record hotkeys directly and browse Ghostty's chord /
  sequence grammar instead of memorising it.
- **Validation lint.** The exact failure mode Ghostty leaves silent (unknown
  keys, bad values) gets flagged up front.
- **Settings provenance.** Per-row popover showing which config file (and
  line) a value actually came from, given the multi-file merge order.
- **Schema-aware, version-forward.** Option metadata is introspected from
  your installed `ghostty` at runtime, so the UI tracks the binary rather than
  hard-coding a schema that churns minor-to-minor.
- **Lossless round-trip.** A custom parser preserves your comments, blank
  lines, ordering, and includes. The app is a companion to the text file,
  never its replacement.
- **Import from Alacritty.** Drop in an Alacritty `.toml` theme and convert it.
- **Live reload.** Edits write through to the config and trigger Ghostty to
  reload (with a restart fallback), plus a file watcher to catch external edits.

### Coverage note

Quite a few areas are still under construction. The sections that 80% of
users actually touch (appearance, fonts, keybinds, windows) came first; the
long tail is being worked through. If you're an open source contributor, poke
at it, find issues, and
[raise them](https://github.com/gouthamganesan/GhosttyConfigurator/issues/new)
so they get fixed.

## Quick start (≈ 30 seconds)

Requires macOS 14+ and Xcode 15.4+.

```bash
git clone https://github.com/gouthamganesan/GhosttyConfigurator.git
cd GhosttyConfigurator
./scripts/bootstrap.sh --open
```

`bootstrap.sh` installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) if
needed (`brew install xcodegen`), generates `GhosttyConfigurator.xcodeproj`
from `project.yml`, and opens it in Xcode. Then press ⌘R.

You can also build from the CLI:

```bash
./scripts/bootstrap.sh
xcodebuild -project GhosttyConfigurator.xcodeproj \
           -scheme GhosttyConfigurator \
           -configuration Debug \
           -derivedDataPath build \
           CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
           build
open build/Build/Products/Debug/GhosttyConfigurator.app
```

## Panes

System-Settings-style sidebar, grouped General · Visual · Behavior · System:

| Pane | Covers |
|---|---|
| **General** | App-level defaults and Quick Terminal |
| **Appearance** | Theme, colors, opacity, the design vocabulary |
| **Window** | Window chrome, padding, splits, tabs |
| **Font** | Family, size, features, font discovery |
| **Cursor** | Style, blink, color |
| **Keyboard** | Keybinds — action catalog + hotkey recorder |
| **Shell** | Shell integration, environment variables |
| **Clipboard & Mouse** | Copy/paste behavior, mouse, links |
| **Advanced** | Custom shaders, escape hatches, raw keys |
| **About** | Version, provenance, schema status |

## Architecture at a glance

| Layer | Where | What |
|---|---|---|
| **Model** | `GhosttyConfigurator/Model/` | `ConfigStore` (observable state), `SchemaStore` (runtime introspection), profiles, keybinds, themes |
| **IO** | `GhosttyConfigurator/IO/` | Config parse/serialize, file watching, theme library + Alacritty import, Ghostty reload, font picker |
| **Validation** | `GhosttyConfigurator/Validation/` | Unknown-key / bad-value lint surfaced as inline badges |
| **Search** | `GhosttyConfigurator/Search/` | Global search across every row in every pane |
| **DesignSystem** | `GhosttyConfigurator/DesignSystem/` | Tokens + System-Settings-parity components (being extracted as [SettingsKit](https://github.com/gouthamganesan/SettingsKit)) |
| **Views** | `GhosttyConfigurator/Views/` | Sidebar + per-pane SwiftUI forms |

## Repo map

| Path | What |
|---|---|
| `docs/00-PLAN.md` | Phased implementation plan. Read this first. |
| `docs/01-design-system.md` | SwiftUI components and design tokens. |
| `docs/02-information-architecture.md` | Sidebar + per-pane row inventory with P0/P1/P2 priority tags. |
| `docs/03-ux-principles.md` | Load-bearing UX rules (this doc wins on conflicts). |
| `docs/04-technical-architecture.md` | Performance budgets, concurrency rules, build configuration. |
| `docs/research-*.md` | Source material (don't re-read unless verifying a synthesis claim). |
| `Configs/` | `.xcconfig` files driving Debug / Release. |
| `GhosttyConfigurator/` | Swift source — App, Model, IO, Search, Validation, DesignSystem, Views, Friendly, Resources. |
| `GhosttyConfiguratorTests/` | Unit + integration tests. |
| `assets/branding/` | Source logo (1254×1254). `scripts/generate-app-icon.sh` rebuilds the icon set. |
| `scripts/` | `bootstrap.sh`, icon generator, ship scripts. |
| `project.yml` | XcodeGen project definition. The `.xcodeproj` is git-ignored and regenerated from this. |

## Design philosophy in one paragraph

System Settings on Sonoma+ is the default rendering of
`NavigationSplitView` + `Form { Section { … } }.formStyle(.grouped)`. Apple
aligned its own app with SwiftUI defaults so third-party apps could match it
for free. Every fight you pick with the framework (custom backgrounds,
hand-drawn toggles, manual NSWindow chrome) takes you *further* from the
System Settings look. The taste move is restraint. See `docs/00-PLAN.md` §1
for the full mental model. The reusable distillation of this lives in
[**SettingsKit**](https://github.com/gouthamganesan/SettingsKit) — a
data-driven settings layer extracted from this app.

## Roadmap

The phased plan lives in `docs/00-PLAN.md`. Open work — including adopting
SettingsKit as the rendering substrate (epic
[#15](https://github.com/gouthamganesan/GhosttyConfigurator/issues/15)) — is
tracked in [Issues](https://github.com/gouthamganesan/GhosttyConfigurator/issues).

## License

[MIT](LICENSE).

Ghostty is © Mitchell Hashimoto — see <https://ghostty.org>. This
configurator is an independent third-party companion, not affiliated.

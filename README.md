# Ghostty Configurator

A native macOS GUI for editing [Ghostty](https://ghostty.org)'s config file —
built to be indistinguishable from System Settings, because on Sonoma+ that
look *is* the SwiftUI default and fighting it only takes you further away.

![logo](assets/branding/logo-source.png)

**Status:** actively developed (v0.1.31). Reads and writes a real Ghostty
config, introspects the live option schema from the installed `ghostty`
binary, and ships a working theme browser, keybind editor, validation lint,
and global search. Not yet a tagged release — see the roadmap below.

## Why this exists

Ghostty has hundreds of config keys and no GUI. A native macOS editor unlocks
the things a text file can't:

- **Theme browser with live preview** — browse the ~300 bundled themes against
  a real terminal preview instead of editing `theme = ?` blind.
- **Keybind editor** — record hotkeys directly and browse Ghostty's chord /
  sequence grammar instead of memorising it.
- **Validation lint** — Ghostty silently ignores typos (`font-familiy = X`
  keeps the default). The GUI flags unknown keys and bad values up front.
- **Schema-aware, version-forward** — option metadata is introspected from
  your installed `ghostty` at runtime, so the UI tracks the binary rather than
  hard-coding a schema that churns minor-to-minor.
- **Import from Alacritty** — drop in an Alacritty `.toml` theme and convert it.
- **Live reload** — edits write through to the config and trigger Ghostty to
  reload (with a restart fallback), plus a file watcher to catch external edits.

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

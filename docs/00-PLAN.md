# GhosttyConfigurator — Implementation Plan

A working document for building a native macOS configurator for Ghostty that looks indistinguishable from System Settings. Updated as decisions are made.

**Read order:** this file first, then [01-design-system.md](./01-design-system.md), then [02-information-architecture.md](./02-information-architecture.md). The three `research-*.md` files are the source material; don't re-read them unless a synthesis claim looks wrong.

---

## 1. Mental model (the one thing to internalize)

> **System Settings is not a custom design — it's the default rendering of `NavigationSplitView` + `.formStyle(.grouped)` on Sonoma+.** Apple aligned its own app with the SwiftUI defaults so third-party apps could match it for free.

Every fight you pick with the framework (custom backgrounds, hand-drawn toggles, manual NSWindow chrome) takes you *further* from the System Settings look, not closer. The taste move is **restraint**.

Two things genuinely require AppKit reach-down: (a) disabling the zoom button, (b) disabling fullscreen. Everything else is declarative.

---

## 2. Scope and target

| Decision | Value | Why |
|---|---|---|
| **Tech stack** | SwiftUI (Swift 5.9+) | Only way to get pixel-perfect System Settings parity for free |
| **OS target** | macOS 14+ (Sonoma) | `NavigationSplitView`, `Window` scene, `.formStyle(.grouped)`, `LabeledContent` all stable here |
| **Platforms** | macOS only | Ghostty is cross-platform; configurator deliberately is not (Tauri/Electron would lose the look) |
| **Distribution** | Direct download (Sparkle auto-update); Mac App Store TBD after v1.0 | Sparkle is friction-free; MAS sandboxing fights config-file access |
| **Goal mix** | Personal use → portfolio → ship to community | Build for self first; harden as you go; ship when polished |
| **Ghostty version target** | 1.2.x baseline, forward-compatible by parsing `+show-config --default --docs` at runtime | Avoid hard-coding the schema; Ghostty's option surface churns minor-to-minor |

---

## 3. The arbitrage — why this project is worth building

Mitchell's team has explicitly said a native GUI is on the roadmap (see ghostty.org/docs/config). That is **both a tailwind and a headwind**: validates the need, but you're building something upstream will eventually ship.

The defensible edge is **stuff Apple's own System Settings paradigm makes hard** for upstream to prioritize:

1. **Theme browser with live preview** — the killer feature. ~300 bundled themes, no GUI to browse them.
2. **Keybind editor with grammar-aware UI** — Ghostty's chord/sequence syntax is dense; UI can collapse the cognitive load.
3. **Validation lint** — Ghostty silently ignores typos (`font-familiy = X` keeps default). A GUI that catches this is high-trust.
4. **Profile / preset management** — work vs personal configs as first-class concept, on top of `config-file = ?` includes.
5. **Provenance** — show *which* config file each value came from, given XDG vs Application Support merge order.
6. **Import from iTerm2 / Alacritty / Windows Terminal** — drag-drop conversion.

If upstream ships a native UI before you, your differentiator is the **richer ecosystem features**, not the basic toggles.

---

## 4. Phased plan

### Phase 0 — Setup (½ day)

- [ ] Xcode project: macOS App, SwiftUI, Swift 5.9+, deployment target macOS 14.0
- [ ] **Create `Configs/Common.xcconfig`, `Debug.xcconfig`, `Release.xcconfig` per [04-technical-architecture.md §3](./04-technical-architecture.md#3-build-configuration--concrete-xcconfig)** — attach to project configurations on day 1
- [ ] **Enable `SWIFT_STRICT_CONCURRENCY = complete` from day 1** — address warnings as you write code, not as you fix prod bugs
- [ ] Set up `.swiftformat` and `.swiftlint.yml` per [research-swift-performance.md §10](./research-swift-performance.md#10-code-style-for-exemplar-swiftui); install pre-commit hook
- [ ] Define repo layout per [04-technical-architecture.md §4](./04-technical-architecture.md#4-repository-layout): `App/`, `Model/`, `IO/`, `DesignSystem/`, `Views/`, `Friendly/`, `Configs/`, `scripts/`, `assets/branding/`
- [ ] **Generate `AppIcon.appiconset` from `assets/branding/logo-source.png`** — downscale source (1254×1254) to 1024×1024, drop into Xcode 14+ "Single Size" app icon slot so it generates all 10 required variants. See [`assets/branding/README.md`](../assets/branding/README.md)
- [ ] **Generate `Logo.imageset`** for in-app use (About pane hero, etc.) at 1x / 2x / 3x from the same source
- [ ] Git init + GitHub repo; GitHub Actions skeleton (`.github/workflows/ci.yml`)
- [ ] Bundle ID, accent color in `Assets.xcassets/AccentColor` (sample the cyan from the logo with Digital Color Meter → save as `Color.brandAccent` in `DesignSystem/Tokens.swift`)
- [ ] One-shot decision: name the app something clear. "Ghostty Configurator", "GhosttyKit", "Phantom" — pick. Recommend **"Ghostty Configurator"** until you have a brand.
- [ ] Add LICENSE (MIT to match Ghostty) and minimal README (use `logo-source.png` as the README banner)

### Phase 1 — Visual skeleton (1–2 days) — *the squint test*

**Goal:** open the app and have someone unable to tell at a glance whether it's System Settings or your app.

- [ ] Implement the minimum viable skeleton from [research-swiftui-system-settings.md §9](./research-swiftui-system-settings.md)
- [ ] `Window` scene, `.windowResizability(.contentSize)`, `WindowAccessor` for `.fullScreenNone` and zoom-button-disable
- [ ] `NavigationSplitView` with `.balanced` style, `columnVisibility: .constant(.all)`, sidebar width pinned to 215pt
- [ ] Sidebar with **placeholder** rows for the 8 sections from [02-information-architecture.md](./02-information-architecture.md), each with a `SidebarIcon` tile
- [ ] One real pane (`AppearancePane`) showing hero card + 2 grouped sections with toggles + a picker + a slider with under-track labels
- [ ] All other panes → `PlaceholderPane(title:)` stub
- [ ] **Squint test:** screenshot your app and Apple's System Settings side-by-side. Diff with eyes only — no measuring. Iterate until indistinguishable.

**Definition of done:** no real Ghostty config IO; UI is hard-coded `@State`. App passes the squint test on Sonoma.

### Phase 2 — Config IO layer (2–3 days)

**Goal:** loaded values appear in the UI; changes write back to disk preserving comments.

- [ ] Custom round-trip parser per [research-ghostty-config.md §7](./research-ghostty-config.md). Internal model: ordered `[Entry]` with `comment`, `blank`, `kv`, `include` variants.
- [ ] Detect Ghostty install: `Ghostty.app` in `/Applications/`; if missing, banner "Install Ghostty to apply changes"
- [ ] Resolve config path: prefer `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`; fall back to XDG; surface choice as a setting
- [ ] Schema introspection: shell out to `ghostty +show-config --default --docs` at first launch, cache JSON-converted result in app support dir. Refresh on Ghostty version change.
- [ ] `ConfigStore` ObservableObject — read + write + diff against defaults
- [ ] Wire `AppearancePane` to real keys (`theme`, `background-opacity`, `background-blur`, `cursor-style`, `font-size`, `font-family`)
- [ ] Reload trigger button: try AppleScript `tell application "Ghostty" to ...`, fallback to "Restart Ghostty" prompt

**Definition of done:** edit a setting in your app → save → reload Ghostty → change is visible. User comments in the config file survive a round-trip.

### Phase 3 — Visual coverage (3–5 days)

Build out remaining panes in priority order. See [02-information-architecture.md](./02-information-architecture.md) for the row-by-row inventory and P0/P1/P2 tags.

Recommended sequence (each pane = ½–1 day):

1. **Appearance** (done in Phase 2)
2. **Window** (`macos-titlebar-style`, padding, decoration)
3. **Cursor** (style, color, blink, opacity)
4. **Font** (family, size, features, ligatures) — font browser uses `NSFontPanel`
5. **Shell** (`shell-integration`, features flags, `command`, `working-directory`)
6. **Clipboard & Mouse** (permissions, paste protection, selection rules)
7. **General** (auto-update, confirm-close, notifications, bell)

Skip for now: Quick Terminal, Keybindings, Advanced/Font Metrics — those are Phase 4+.

### Phase 4 — Theme browser (3–4 days) — *the killer feature*

- [ ] Enumerate themes via `ghostty +list-themes` OR by walking `Ghostty.app/Contents/Resources/ghostty/themes/` + `~/.config/ghostty/themes/`
- [ ] Parse each theme file (reuse the round-trip parser) to extract palette + bg/fg
- [ ] Theme grid view: each tile = swatches (16 ANSI colors) + bg/fg sample text
- [ ] Theme detail: full preview pane showing a faux terminal with realistic content (shell prompt, ls output, syntax highlighting)
- [ ] Search + filter (light/dark, hue, source)
- [ ] **Light/dark pair UI** — single toggle "Switch with system appearance" that exposes two pickers, writes `theme = light:X,dark:Y`
- [ ] Apply: write `theme = ...` and trigger reload
- [ ] **Stretch**: import from iTerm2 `.itermcolors`, Alacritty `.toml`, Windows Terminal `.json`

### Phase 5 — Keybind editor (4–6 days) — *the hardest UI*

This is its own design problem. Plan separately when you get here. Skeleton thoughts:

- [ ] Two-column: trigger on left, action on right, with chord-arrow flow
- [ ] Trigger capture widget: live-record key combo; render as macOS shortcut glyphs (⌘⇧A)
- [ ] Action picker: searchable list of 80 actions, with action-specific parameter inputs
- [ ] Prefix toggles: `all:`, `global:`, `unconsumed:`, `performable:` as chips on the trigger
- [ ] Sequence builder: "add next chord" button to extend a trigger
- [ ] Conflict detection: warn when new binding shadows existing
- [ ] Diff against defaults: show "Reset to default" per binding, "Reset all" for the pane
- [ ] **Defer chord/sequence editing** to v1.1 — most users don't use it; ship simple bindings first

### Phase 6 — Polish (2–3 days)

- [ ] Global search (the System Settings search field at top of sidebar) — fuzzy-match across all rows
- [ ] Settings provenance: per-row info popover showing source file + line
- [ ] Validation lint: highlight rows where current value would error against schema (unknown enum, out-of-range)
- [ ] Profile/preset management: dropdown in toolbar — "Personal / Work / ..." driven by `config-file = ?profile-name.ghostty` includes
- [ ] Empty states, loading states, error states
- [ ] Dark mode parity check (most should be free; verify hero icons + theme browser)
- [ ] Accessibility: keyboard navigation through every control, VoiceOver labels

### Phase 7 — Ship (1–2 days + ongoing)

- [ ] App icon — **already available** at `assets/branding/logo-source.png`. Verify the `AppIcon.appiconset` was generated cleanly in Phase 0 and renders correctly in the Dock at all sizes (squircle mask preserves the design); regenerate from source if any variant looks off
- [ ] **Run `scripts/preship.sh` and verify every hard limit in [04-technical-architecture.md §1](./04-technical-architecture.md#1-the-performance-contract)** passes
- [ ] Code signing + notarization (see [research-bundle-and-build.md §7](./research-bundle-and-build.md#7-code-signing-notarization-distribution) for full pipeline)
- [ ] ~~Sparkle integration for auto-update~~ — **deferred to v1.x** ([04-technical-architecture.md §5.1](./04-technical-architecture.md#51-no-sparkle-in-v10))
- [ ] DMG with background image via `create-dmg`
- [ ] GitHub Release (primary distribution channel)
- [ ] Homebrew Cask formula PR (secondary channel, fast-follow)
- [ ] Landing page (GitHub Pages or simple Vercel) with download + screenshots
- [ ] Announce on Ghostty Discord, r/MacOS, Hacker News (only when truly ready)
- [ ] Telemetry decision: **opt-in only, anonymized** — what panes are used, error rates. No PII, no config contents.

---

## 5. Risks and what could go wrong

| Risk | Likelihood | Mitigation |
|---|---|---|
| Ghostty schema churn between minor versions breaks the configurator | High | Runtime introspection via `+show-config --default --docs`; never hard-code enums |
| Mitchell ships an official GUI before v1 | Medium | Focus the differentiator (theme browser, keybind editor, profiles) — don't try to be 1:1 with native |
| `Form { ... }.formStyle(.grouped)` rendering changes in macOS 15/16 | Medium | Test on each new beta; lean on system defaults so changes are inherited, not broken |
| Sandbox restrictions prevent reading Ghostty's bundle resources (themes, docs) | Medium | Don't sandbox the app initially; if MAS becomes target later, add bookmarks for Ghostty.app |
| Reload mechanism unreliable (AppleScript permissions, accessibility prompts) | Medium | Always offer "Restart Ghostty" as fallback; document permission setup clearly |
| Custom parser misses an edge case in user configs and corrupts comments on save | High (subtle) | Snapshot test every config change against a corpus of real-world configs; never overwrite if parse fails |
| User's config has `config-file =` includes pointing to large/external trees | Low | Resolve include graph lazily; write only to the file the user is currently editing |

---

## 6. Design principles (rules of taste, not features)

1. **Mirror System Settings unless there's a reason not to.** Don't innovate on UI patterns. Innovate on Ghostty-specific things (theme preview, keybind grammar).
2. **System primitives > hand-tuned pixels.** Every hex value or magic number you hard-code is a future maintenance debt. Use `Color.accentColor`, `Color(NSColor.controlBackgroundColor)`, system fonts at named text styles.
3. **Round-trip the user's file losslessly.** Comments, blank lines, ordering, multi-file includes — all preserved. The configurator is a *companion* to the text file, not its replacement.
4. **Default to revealing, not hiding, what Ghostty does.** When a value requires restart, say so. When a value comes from an included file, say so. When two files set the same key, surface the conflict.
5. **Restraint over completeness.** Don't expose all 188 keys at v1. Hide the 30 most-niche behind "Advanced" disclosures or omit entirely. Users who need them already edit the text file.
6. **Live preview is the moat.** Anywhere a setting changes visible terminal output (colors, font, opacity, cursor), show a real-time preview. This is the thing the text file *cannot* do.

### UX principles — non-negotiable (see [03-ux-principles.md](./03-ux-principles.md) for full detail)

7. **Abstract config syntax from users.** Never expose raw flags or grammar (`-calt`, `search_selection`, `light:X,dark:Y`). Translate to friendly controls. Power users get the verbatim docs via a tooltip on every row.
8. **Session-based pending changes.** Edits buffer in-memory; a "Pending Changes" section appears at the top of the sidebar; user reviews then Saves All. No auto-save per toggle. `⌘S` saves.
9. **Modification-state dots.** Blue dot after a label = modified from default and saved. Yellow dot = unsaved session edit. No dot = at default.
10. **Live previews are mandatory** for anything visually rendered (theme, font, cursor, opacity). Shared `TerminalPreview` component with terminal-style syntax highlighting (not IDE-style).
11. **Help is one click away.** Every row that maps to a Ghostty key has an info button showing the verbatim docs entry. About pane links to all upstream Ghostty docs pages.

---

## 7. Decisions deferred

Log here as they come up.

- App icon design — commission vs solo
- Whether to support Linux/GTK keys at all (probably no — out of scope, see IA doc)
- MAS submission — defer; ship via direct download first
- Telemetry — opt-in only; choose Plausible/PostHog/none
- Theme contribution flow — should the app help users *publish* themes back to a community gallery?

---

## 8. References within this repo

- [research-swiftui-system-settings.md](./research-swiftui-system-settings.md) — SwiftUI implementation patterns, code snippets, pitfalls, minimum viable skeleton
- [research-macos-hig-specs.md](./research-macos-hig-specs.md) — pixel/typography specs from Apple HIG with measurement caveats
- [research-ghostty-config.md](./research-ghostty-config.md) — full Ghostty config surface (188 keys + 80 actions), parser strategy, keybind grammar
- [research-swift-performance.md](./research-swift-performance.md) — SwiftUI/Swift performance patterns and modern architecture (Observable, MainActor, launch time)
- [research-bundle-and-build.md](./research-bundle-and-build.md) — bundle size, build optimization, code signing, Sparkle, CI/CD
- [01-design-system.md](./01-design-system.md) — distilled SwiftUI components to build
- [02-information-architecture.md](./02-information-architecture.md) — sidebar sections + per-pane row inventory with priority tags
- [03-ux-principles.md](./03-ux-principles.md) — load-bearing UX rules (config-syntax abstraction, pending changes, dots, previews, doc tooltips)
- [04-technical-architecture.md](./04-technical-architecture.md) — performance budgets, concurrency rules, build configuration, profiling discipline
- [source/](./source/) — saved HTML mirrors of Ghostty official docs; use for per-option deep dives during implementation

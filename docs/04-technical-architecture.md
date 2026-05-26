# Technical Architecture — Performance Budgets, Concurrency, Build Discipline

The CTO-grade implementation plan: what gets built, what gets measured, what gets rejected. Distilled from [research-swift-performance.md](./research-swift-performance.md) and [research-bundle-and-build.md](./research-bundle-and-build.md). This doc is normative — if your code doesn't conform, the code is wrong, not the doc.

> **One-line philosophy.** Know what's in your binary, by line if you have to. A 188-row config GUI has no business shipping at 50MB and 800ms cold launch. Every byte and every millisecond must be justified.

---

## 1. The performance contract

These are non-negotiable budgets. CI fails the build if any are violated. Each release tag re-runs the profiling pre-ship script ([§6](#6-discipline-what-gets-measured-when)).

| Metric | Hard limit | Aspirational target | How measured |
|---|---|---|---|
| Cold launch (Dock click → first frame) | **< 200 ms** | < 100 ms | Instruments → App Launch, Release build, Apple Silicon, post-reboot |
| First user input latency | **< 16 ms** (1 frame @ 60Hz) | < 8 ms | Instruments → SwiftUI hitches metric |
| Memory at idle (one window, no action) | **< 50 MB RSS** | < 40 MB | `ps -o rss -p <pid>` after 30s idle |
| Memory peak (Theme Browser fully loaded) | **< 100 MB RSS** | < 80 MB | Instruments → Allocations, mark+sweep |
| CPU at idle (foreground, no interaction) | **0.0 %** sampled over 60 s | 0.0 % | Activity Monitor |
| Energy impact (Xcode gauge) | **"Low"** or below | "No" | Xcode Debug Navigator → Energy |
| Executable size (Mach-O) | **< 5 MB** | < 3 MB | `ls -la *.app/Contents/MacOS/*` |
| `.app` bundle size | **< 8 MB** without Sparkle | < 6 MB | `du -sh *.app` |
| DMG size (compressed, signed, stapled) | **< 15 MB** | < 10 MB | `ls -la *.dmg` |
| Leaks (Instruments) | **0** | 0 | Instruments → Leaks, 5-min exercise script |
| Retain cycles | **0** | 0 | Memory Graph Debugger |
| SwiftUI scroll hitches | **0** | 0 | Instruments → SwiftUI; theme browser scroll |
| Compiler warnings | **0** | 0 | `OTHER_SWIFT_FLAGS = -warnings-as-errors` in Release |
| Force unwraps (`!`) in shipping code | **0** | 0 | SwiftLint `force_unwrapping: error` |

**The hard limits are CI gates.** If a PR regresses any of them, it doesn't merge. The aspirational targets are stretch goals — measure but don't gate.

---

## 2. Architecture — data flow, ownership, concurrency

### 2.1 The three actors

```
                    ┌──────────────────────────────────┐
                    │            MainActor             │
                    │  ┌────────────────────────────┐  │
                    │  │  @Observable ConfigStore   │  │
                    │  │   - onDisk:   Config       │  │
                    │  │   - session:  SessionEdits │  │
                    │  │   - effective (computed)   │  │
                    │  └────────────┬───────────────┘  │
                    │               │                  │
                    │       SwiftUI views read         │
                    │       effective via @Bindable    │
                    └───────────────┬──────────────────┘
                                    │ async/await
                ┌───────────────────┼────────────────────┐
                │                                        │
                ▼                                        ▼
    ┌─────────────────────┐                ┌────────────────────────┐
    │   actor             │                │   actor                │
    │   ConfigFileIO      │                │   ThemeLibrary         │
    │   - read/parse      │                │   - lazy theme load    │
    │   - serialize/write │                │   - palette extraction │
    │   - watch (FSEvents)│                │   - bounded NSCache    │
    └─────────────────────┘                └────────────────────────┘
```

**Rules:**

1. **`ConfigStore` is `@Observable @MainActor`.** All UI reads it directly; no detour through a "view model" class per pane.
2. **All I/O is `nonisolated` and `async`.** Read/parse/serialize/write live in `actor ConfigFileIO`. Theme loading lives in `actor ThemeLibrary`. Neither ever touches MainActor state — they return `Sendable` values, the store re-enters MainActor on the await.
3. **No `Combine`.** Period. `@Observable` + `async`/`await` + `AsyncStream` for FSEvents covers everything.
4. **No `DispatchQueue.main.async`.** Use `Task { @MainActor in ... }` or restructure to async.
5. **No `Task.detached` unless you truly mean it.** Almost never needed in this app.

### 2.2 The session-edit model (UX Principle 2)

```swift
@Observable
@MainActor
final class ConfigStore {
    // MARK: - Stored properties

    /// Last-read disk snapshot. Mutated only on load() / save().
    private(set) var onDisk: Config

    /// In-session edits keyed by canonical Ghostty key path.
    /// Cleared on saveAll() and discardAll().
    private(set) var session: [ConfigKey: ConfigValue] = [:]

    /// User-facing config: onDisk overlaid with session.
    /// This is what every SwiftUI binding reads.
    var effective: Config {
        onDisk.applying(session)
    }

    /// True when there are unsaved changes (pending changes section).
    var hasPendingChanges: Bool { !session.isEmpty }

    let fileURL: URL
    private let io: ConfigFileIO
    private var watcherTask: Task<Void, Never>?
    private var suppressNextReload = false
}
```

**Why this matters for performance:**
- `effective` is computed, not stored. The apply is O(session.count), not O(188). For typical sessions (0-10 edits) it's free.
- `@Observable` tracks reads at the key-path level — a view that reads `effective.cursorColor` won't invalidate when `effective.fontFamily` changes, even though both flow through the same computed property. *(Verify with `Self._printChanges()` during early dev.)*
- If observation granularity turns out coarser than hoped on a computed property, fall back to per-key `@Observable` overlay: a dictionary of `@Observable` cell objects. Decision deferred until measurement says it matters.

### 2.3 Concurrency rules — discipline

| Rule | Why |
|---|---|
| `@MainActor` on `ConfigStore`, all views | UI work stays on main; framework expects it |
| All file I/O in `nonisolated async` functions | Off-main; doesn't hitch UI |
| `try Task.checkCancellation()` at I/O boundaries | Cooperative cancellation; respects view lifecycle |
| Explicit `[weak self]` in escaping closures and long-lived `Task` loops | No retain cycles, no leaks |
| `SWIFT_STRICT_CONCURRENCY = complete` from day 1 | Catch races at compile time, not in prod |
| `Sendable` on every type that crosses actor boundaries (`Config`, `Keybinding`, `Theme`) | Compile-time safety |
| FSEvents bridged via `AsyncStream<Event>` | Idiomatic, cancellation-safe |
| `.task(id:)` for view-bound async work | Auto-cancels on view disappear |

### 2.4 What's allowed in `App.init` and `App.body`

**Allowed:**
- Construct an *empty* `ConfigStore` (no file read).
- Declare the `Window` scene + `WindowAccessor` + commands.

**Banned:**
- File I/O (defer to `.task`).
- Theme enumeration (defer to `actor ThemeLibrary` on first need).
- `NSWorkspace` observers (defer to `.task` on root view).
- Schema introspection (defer to `.task` at root; cache result).
- Any synchronous parse, JSON decode, or PLIST load.

The single mantra: **the first frame must render with placeholder data if necessary. Real data arrives via `.task`.**

---

## 3. Build configuration — concrete `.xcconfig`

Three files, checked into git, attached to the project's configurations.

### `Configs/Common.xcconfig`

```
PRODUCT_NAME = GhosttyConfigurator
PRODUCT_BUNDLE_IDENTIFIER = com.gouthamj.ghostty-configurator
MARKETING_VERSION = 0.1.0
CURRENT_PROJECT_VERSION = 1
DEVELOPMENT_LANGUAGE = en

MACOSX_DEPLOYMENT_TARGET = 14.0
ARCHS = arm64
EXCLUDED_ARCHS = x86_64
VALID_ARCHS = arm64
SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO

SWIFT_VERSION = 5.9
SWIFT_STRICT_CONCURRENCY = complete

ENABLE_USER_SCRIPT_SANDBOXING = YES
ENABLE_HARDENED_RUNTIME = YES
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = Apple Development

INFOPLIST_FILE = GhosttyConfigurator/Info.plist
INFOPLIST_KEY_NSHumanReadableCopyright = Copyright © 2026 Goutham Ganesan. MIT License.
INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.developer-tools

ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor

GENERATE_INFOPLIST_FILE = YES
DEVELOPMENT_TEAM = $(inherited)
```

### `Configs/Debug.xcconfig`

```
#include "Common.xcconfig"

SWIFT_OPTIMIZATION_LEVEL = -Onone
SWIFT_COMPILATION_MODE = singlefile
GCC_OPTIMIZATION_LEVEL = 0
ONLY_ACTIVE_ARCH = YES
DEBUG_INFORMATION_FORMAT = dwarf

ENABLE_TESTABILITY = YES
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
GCC_PREPROCESSOR_DEFINITIONS = DEBUG=1 $(inherited)

ENABLE_NS_ASSERTIONS = YES
COPY_PHASE_STRIP = NO
DEAD_CODE_STRIPPING = NO
```

### `Configs/Release.xcconfig`

```
#include "Common.xcconfig"

SWIFT_OPTIMIZATION_LEVEL = -Osize
SWIFT_COMPILATION_MODE = wholemodule
GCC_OPTIMIZATION_LEVEL = s
LLVM_LTO = YES_THIN
ONLY_ACTIVE_ARCH = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym

ENABLE_TESTABILITY = NO
SWIFT_ACTIVE_COMPILATION_CONDITIONS =
GCC_PREPROCESSOR_DEFINITIONS = $(inherited)

ENABLE_NS_ASSERTIONS = NO
COPY_PHASE_STRIP = NO
DEAD_CODE_STRIPPING = YES
STRIP_INSTALLED_PRODUCT = YES
STRIP_STYLE = all
STRIP_SWIFT_SYMBOLS = YES
DEPLOYMENT_POSTPROCESSING = YES
SEPARATE_STRIP = YES
SWIFT_DISABLE_SAFETY_CHECKS = NO

VALIDATE_PRODUCT = YES
OTHER_SWIFT_FLAGS = $(inherited) -warnings-as-errors

ASSETCATALOG_COMPILER_OPTIMIZATION = space
ENABLE_INCREMENTAL_DISTILL = NO

OTHER_LDFLAGS = $(inherited) -Wl,-dead_strip -Wl,-dead_strip_dylibs
```

**Rationale highlights** (full detail in [research-bundle-and-build.md §2](./research-bundle-and-build.md)):
- `-Osize` over `-O`: the hot path is in SwiftUI, not our code; size matters more than micro-perf
- `wholemodule` + `LLVM_LTO = YES_THIN`: the two biggest leverage points after `-O`
- `STRIP_SWIFT_SYMBOLS = YES`: removes reflection metadata we don't use
- `-warnings-as-errors` in Release only: hygiene without dev pain
- `COPY_PHASE_STRIP = NO` with `STRIP_INSTALLED_PRODUCT = YES`: the Apple-recommended combo; `COPY_PHASE_STRIP = YES` mangles Swift frameworks

### Framework dependency budget

Allowed:
- `SwiftUI`
- `AppKit` (only for `NSWindow` reach-down via `WindowAccessor`; consider removing if `MenuBarExtra` covers everything)
- `Foundation`
- `os` (built-in; `Logger`, signposts)
- `Observation` (built-in; `@Observable`)

Banned without specific justification:
- `Combine` — use `@Observable` + `async`/`await`
- `CoreData` / `SwiftData` — config is a text file, not a database
- `Charts`, `MapKit`, `WebKit`, `AVFoundation`, `MediaPlayer` — none needed
- Any third-party SwiftUI helpers (SnapKit, Alamofire, Kingfisher, etc.) — overkill
- Sparkle — deferred to v1.x (see Decisions §5.1)

### Logging

```swift
import os
extension Logger {
    private static let subsystem = "com.gouthamj.ghostty-configurator"
    static let app     = Logger(subsystem: subsystem, category: "app")
    static let store   = Logger(subsystem: subsystem, category: "store")
    static let parser  = Logger(subsystem: subsystem, category: "parser")
    static let watcher = Logger(subsystem: subsystem, category: "watcher")
    static let themes  = Logger(subsystem: subsystem, category: "themes")
    static let launch  = Logger(subsystem: subsystem, category: "launch")
}
```

`print()` is banned everywhere. SwiftLint should be configured to flag it.

---

## 4. Repository layout

```
GhosttyConfigurator/
├── Configs/
│   ├── Common.xcconfig
│   ├── Debug.xcconfig
│   └── Release.xcconfig
├── GhosttyConfigurator.xcodeproj/
├── GhosttyConfigurator/
│   ├── App/
│   │   ├── GhosttyConfiguratorApp.swift
│   │   ├── ContentView.swift
│   │   ├── WindowAccessor.swift
│   │   └── Commands/
│   │       └── ConfigCommands.swift
│   ├── Model/
│   │   ├── Config.swift                  // value type; all 188 keys grouped
│   │   ├── Config+Defaults.swift
│   │   ├── ConfigKey.swift               // enum of canonical keys
│   │   ├── Keybinding.swift
│   │   ├── Theme.swift
│   │   └── ConfigStore.swift             // @Observable @MainActor
│   ├── IO/
│   │   ├── ConfigFileIO.swift            // actor: read/write/serialize
│   │   ├── ConfigParser.swift            // round-trip parser
│   │   ├── ConfigSerializer.swift
│   │   ├── FileWatcher.swift             // DispatchSource → AsyncStream
│   │   └── ThemeLibrary.swift            // actor: lazy theme loading
│   ├── DesignSystem/
│   │   ├── Tokens.swift                  // semantic color/font aliases
│   │   ├── SidebarIcon.swift
│   │   ├── HeroCard.swift
│   │   ├── SystemSettingsSlider.swift
│   │   ├── ModificationIndicator.swift
│   │   ├── DocTooltip.swift
│   │   ├── RowAffix.swift
│   │   ├── PendingChangesSection.swift
│   │   └── TerminalPreview.swift
│   ├── Views/
│   │   ├── Sidebar/
│   │   │   ├── Sidebar.swift
│   │   │   └── SidebarSection.swift
│   │   └── Panes/
│   │       ├── AppearancePane.swift
│   │       ├── WindowPane.swift
│   │       ├── FontPane.swift
│   │       ├── CursorPane.swift
│   │       ├── ShellPane.swift
│   │       ├── KeyboardPane.swift
│   │       ├── ClipboardAndMousePane.swift
│   │       ├── GeneralPane.swift
│   │       ├── AdvancedPane.swift
│   │       └── AboutPane.swift
│   ├── Friendly/
│   │   ├── ActionLabels.swift            // 80-entry friendly label dict
│   │   ├── FontFeatureCatalog.swift      // checkbox UI ↔ +/- flags
│   │   └── KeybindFormatter.swift        // chord → macOS glyphs
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   │   ├── AppIcon.appiconset/       // generated from assets/branding/logo-source.png
│   │   │   ├── Logo.imageset/            // in-app use (About pane); 1x/2x/3x from same source
│   │   │   └── AccentColor.colorset/     // brand cyan sampled from the logo
│   │   └── Info.plist
│   └── Logging.swift                     // Logger categories
├── assets/
│   └── branding/
│       ├── logo-source.png               // 1254×1254 master; check into git
│       └── README.md                     // conversion guide
├── GhosttyConfiguratorTests/
│   ├── ConfigParserTests.swift
│   ├── ConfigSerializerTests.swift
│   ├── RoundtripTests.swift              // corpus of real user configs
│   ├── ThemeParserTests.swift
│   └── Fixtures/
│       └── *.ghostty                     // input files
├── scripts/
│   ├── release.sh
│   ├── preship.sh                        // runs the §6 checklist
│   ├── notarize.sh
│   └── generate-app-icon.sh              // sips-based generator from logo-source.png
├── .swiftformat
├── .swiftlint.yml
├── .github/
│   └── workflows/
│       ├── ci.yml                         // PR builds + tests
│       └── release.yml                    // tag-triggered notarized DMG
├── docs/                                  // this directory
├── LICENSE
└── README.md
```

One primary type per file. `// MARK: -` discipline inside types (see [research-swift-performance.md §10](./research-swift-performance.md#10-code-style-for-exemplar-swiftui)).

---

## 5. Decisions log (with justification)

### 5.1 No Sparkle in v1.0

**Decision:** Ship without auto-update for the first stable release. Distribute via GitHub Releases + Homebrew Cask only.

**Why:** Saves ~3MB binary, eliminates the EdDSA key + appcast + Sparkle release pipeline. The Ghostty user base lives in Homebrew — `brew upgrade --cask ghostty-configurator` is idiomatic. Adds an auto-update channel after v1.1 if install-base staleness becomes a real problem.

**Revisit when:** GitHub Releases analytics show > 50% of issues are filed against versions > 30 days behind current.

### 5.2 Apple Silicon only

**Decision:** Ship `ARCHS = arm64` only. No Intel slice.

**Why:** macOS 14 already nudges Intel users out; new OSS tools shouldn't pay the universal-binary tax for an Intel long tail outside Apple's support runway. Halves binary size, simplifies build matrix.

**Revisit when:** A vocal Intel user files an issue. Reply: build `-intel` artifact from CI as a separate download — don't bloat everyone's bundle.

### 5.3 `@Observable` everywhere, `ObservableObject` nowhere

**Decision:** No `ObservableObject`, no `@Published`, no `@StateObject`, no `@ObservedObject`, no `@EnvironmentObject` anywhere in the codebase. SwiftLint rule to ban these.

**Why:** Coarse vs fine invalidation. With ~188 config fields and ~10 panes, `ObservableObject`'s "any change invalidates every view holding the object" model wastes O(panes × edits) view-body evaluations. `@Observable`'s key-path tracking is O(touched keys). Difference is the entire performance budget.

### 5.4 Round-trip parser, never destructive rewrite

**Decision:** The config parser preserves user comments, blank lines, and key ordering. Saves are surgical edits to existing lines, additions, or removals — never a from-scratch serialize.

**Why:** Most Ghostty users hand-author their config and annotate it heavily. A configurator that strips their comments is unusable. Mirrors how `git config`, `defaults`, `gh config set` work.

**Implication:** ConfigParser's tests must round-trip a corpus of real user configs (Ghostty community dotfile repos) with zero diff. CI gate.

### 5.5 No Combine

**Decision:** Don't `import Combine`. Use `@Observable` + `async`/`await` + `AsyncStream` for FSEvents.

**Why:** Combine is in maintenance mode at Apple. Swift Concurrency is the explicit successor. Pulling in Combine is bytes + cognitive surface for zero unique capability.

### 5.6 `nonisolated` async for all I/O

**Decision:** `ConfigFileIO` is an `actor`. All read/parse/write methods are `nonisolated` (where pure) or actor-isolated. `ConfigStore.load()` is `@MainActor` async; it awaits `ConfigFileIO` and re-enters MainActor implicitly.

**Why:** Keeps MainActor sacred. ~10KB file parse takes < 1ms but the discipline matters more than the time — it sets the pattern for theme browser (300 files) and future heavier work.

### 5.7 Lazy theme loading via `actor ThemeLibrary`

**Decision:** Enumerate theme filenames at first need; load and parse individual theme files on demand; cache in actor with bounded eviction via `NSCache`.

**Why:** 300 themes × ~5KB = 1.5MB of resident memory if eagerly loaded. None of it serves the user until they open Theme Browser. Lazy loading saves the memory and ~150-300ms of cold-launch time.

### 5.8 Custom Ghostty parser, not a third-party INI library

**Decision:** Write a custom parser/serializer for Ghostty's `key = value` format. ~300 lines of Swift.

**Why:** The format isn't INI despite the highlighter — repeat keys for lists, `key =` empty-resets-to-default semantics, `config-file = ?optional` includes, comment-preservation. No library handles all of these. Hand-written parser is the only correct option.

### 5.9 SwiftPM only, exact-pinned versions

**Decision:** Only SwiftPM dependencies. Every dependency pinned to exact version (`exact: "X.Y.Z"`), not ranges. `Package.resolved` committed.

**Why:** Supply-chain hygiene. Range pins are how surprises ship. Exact pins make every build reproducible.

---

## 6. Discipline — what gets measured when

### 6.1 Pre-commit (local, on every commit)

- `swiftformat .` — formatting; fails commit if non-conformant
- `swiftlint --strict` — fails commit on any warning
- `swift test` (fast tests only) — parser + serializer round-trip suite

### 6.2 PR CI (GitHub Actions on every PR)

- Build Debug + Release configurations on `macos-14` runner with pinned Xcode
- Full `swift test` suite including round-trip corpus
- `swiftlint --strict` and `swiftformat --lint`
- Build size check: fail if Release `.app` exceeds 8 MB

### 6.3 Pre-tag (manual + `scripts/preship.sh`)

Before tagging any release, run on a Release build:

```bash
./scripts/preship.sh
```

The script checks every hard limit in [§1](#1-the-performance-contract):

```bash
#!/usr/bin/env bash
set -euo pipefail

APP=build/export/GhosttyConfigurator.app
DMG=build/GhosttyConfigurator.dmg

# Size gates
APP_SIZE=$(du -k "$APP" | cut -f1)
DMG_SIZE=$(du -k "$DMG" | cut -f1)
EXE_SIZE=$(du -k "$APP/Contents/MacOS/GhosttyConfigurator" | cut -f1)

(( APP_SIZE < 8192 )) || { echo "FAIL: .app size $APP_SIZE KB > 8 MB"; exit 1; }
(( DMG_SIZE < 15360 )) || { echo "FAIL: DMG size $DMG_SIZE KB > 15 MB"; exit 1; }
(( EXE_SIZE < 5120 )) || { echo "FAIL: executable $EXE_SIZE KB > 5 MB"; exit 1; }

# Linked frameworks check
LINKED=$(otool -L "$APP/Contents/MacOS/GhosttyConfigurator" | grep -v "^$APP" | wc -l)
(( LINKED < 30 )) || { echo "FAIL: $LINKED linked dylibs (expected < 30)"; otool -L "$APP/Contents/MacOS/GhosttyConfigurator"; exit 1; }

# Signing + notarization
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute "$APP" -vvv
codesign --verify --deep --strict --verbose=2 "$APP"

# Hardened runtime
codesign --display --verbose=4 "$APP" 2>&1 | grep -q "runtime" || { echo "FAIL: hardened runtime missing"; exit 1; }

echo "ALL CHECKS PASSED. Ship it."
```

Plus manual:
- Instruments → App Launch (Release, post-reboot): launch < 200ms
- Instruments → Allocations: idle < 50MB, peak < 100MB
- Instruments → Leaks: 0 leaks
- Memory Graph Debugger: 0 retain cycles
- Activity Monitor: 0.0% CPU at idle for 60s

If any check fails, do not tag.

### 6.4 Profiling cadence

- **Every PR touching ConfigStore, ConfigParser, or any view:** add an Instruments run note to the PR description if you suspect impact.
- **Every release:** full pre-ship script.
- **Quarterly:** review the budgets — if they're too easy or too hard, adjust with explicit justification in this doc's git history.

---

## 7. Risks and what could go wrong

| Risk | Likelihood | Mitigation |
|---|---|---|
| `@Observable` on computed `effective: Config` gives coarse invalidation | Medium | Test with `Self._printChanges()` early in Phase 1; if coarse, fall back to per-key overlay model |
| FSEvents fires on our own atomic write, causes save-reload loop | High | `suppressNextReload` flag set before every write; tested with integration test |
| Parser corrupts a real user's config (loses comments, reorders keys) | High | Round-trip corpus test against community dotfiles in CI; snapshot tests |
| macOS 15/16 changes `Form.formStyle(.grouped)` rendering | Medium | Test on every Apple beta; rely on system defaults so we inherit changes |
| Theme library at 300 themes shows visible scroll hitch | Low | `LazyVStack` if it does; profile with Instruments before optimizing |
| Sparkle decision (skip) leaves install base stale | Low | Monitor GitHub issues; revisit at v1.1 if needed |
| Notarization fails on first attempt due to Apple service issues | Medium | `release.sh` runnable locally as fallback; retry mechanism in CI |
| `SWIFT_STRICT_CONCURRENCY = complete` produces many warnings | High | Address in Phase 1; this is the right pain to take early |

---

## 8. How this doc plugs into the phased plan

Phase mapping ([00-PLAN.md](./00-PLAN.md)) updates:

- **Phase 0 — Setup**: Create the three `.xcconfig` files immediately. Set up SwiftFormat + SwiftLint + pre-commit hook. Configure GitHub Actions skeleton. Define `Configs/`, `scripts/`, and `assets/branding/` directories. Generate `AppIcon.appiconset` + `Logo.imageset` from `assets/branding/logo-source.png` via `scripts/generate-app-icon.sh` (sips-based).
- **Phase 1 — Visual skeleton**: Build with `SWIFT_STRICT_CONCURRENCY = complete` from day one. `@Observable` ConfigStore even if it holds hardcoded state. Verify cold launch < 200ms.
- **Phase 2 — Config IO**: Implement `ConfigFileIO` as actor with `nonisolated` async methods. `FileWatcher` per [research-swift-performance.md §7](./research-swift-performance.md#7-file-io-for-a-config-file-app). Round-trip corpus test gate.
- **Phase 3 — Visual coverage**: Every new pane must measure cold launch and memory before merge. Per-pane size budget: each new pane adds < 200 KB to release `.app`.
- **Phase 4 — Theme Browser**: `actor ThemeLibrary` per [§5.7](#57-lazy-theme-loading-via-actor-themelibrary). Profile memory peak — must stay < 100 MB.
- **Phase 5 — Keybind editor**: No special perf rules; same discipline as other panes.
- **Phase 6 — Polish**: Run the full pre-ship checklist; resolve every gap.
- **Phase 7 — Ship**: Notarize, DMG, GitHub Release, Homebrew Cask PR. Sparkle deferred.

---

## 9. The two unambiguous commitments

1. **Cold launch < 200ms, idle CPU 0%, RSS < 50MB.** Hard limits. CI-enforced. Not negotiable.
2. **Zero compiler warnings, zero force unwraps, zero retain cycles.** Code that ships looks like code that Apple's SwiftUI team would write.

Every other decision flexes around these two. If a feature would break either, the feature gets cut or redesigned.

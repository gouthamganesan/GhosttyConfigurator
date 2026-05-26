# Research: macOS Bundle Size, Build Optimization, and Distribution

A CTO-grade playbook for a single-purpose SwiftUI configurator app on macOS 14+. Opinionated. Concrete. Every setting is named with its actual key and recommended value.

**A note on sources:** Apple's developer docs are JavaScript-rendered and WebFetch returned only page titles, so I cannot quote them verbatim. URLs below are correct entry points; values come from prior knowledge of Xcode 15/16 build systems and the Sparkle 2.x project. Where I'm extrapolating rather than citing, I've flagged it with *(verify)*.

---

## 1. Bundle Size Minimization

**Principle.** A SwiftUI configurator should be < 5MB unsigned, < 10MB with Sparkle, < 15MB as a DMG. Everything in the bundle that isn't actively serving the user is technical debt: dead Swift symbols, fat-binary slices, uncompressed PNGs, debug metadata, leftover dSYMs in the wrong place. Strip aggressively; ship narrowly.

**What's actually in a typical SwiftUI Mac app bundle:**
- `MyApp.app/Contents/MacOS/MyApp` — the Mach-O executable (often 60-80% of size; Swift symbol tables are the bulk)
- `Contents/Resources/Assets.car` — compiled asset catalog
- `Contents/Resources/*.lproj/` — localization (English-only? delete the rest)
- `Contents/Frameworks/` — embedded dynamic frameworks (Sparkle lives here; otherwise should be empty for a SwiftUI-only app)
- `Contents/Info.plist`, `Contents/PkgInfo`, `Contents/_CodeSignature/`
- Sometimes: `Contents/Resources/Base.lproj/Main.storyboard` — you don't need this in pure SwiftUI; delete it and set `NSPrincipalClass = NSApplication` + `NSMainStoryboardFile` *removed* from Info.plist.

**Build settings — set these in a `.xcconfig` per configuration:**

```
// Common.xcconfig (both Debug and Release)
ONLY_ACTIVE_ARCH = YES                  // Debug builds only your arch
ENABLE_USER_SCRIPT_SANDBOXING = YES     // Xcode 15+ default; keep it
SWIFT_STRICT_CONCURRENCY = complete     // free correctness; no size cost

// Release.xcconfig
DEAD_CODE_STRIPPING = YES               // linker -dead_strip
STRIP_INSTALLED_PRODUCT = YES           // strip executable on install
COPY_PHASE_STRIP = NO                   // counter-intuitive: NO is correct
                                        // (stripping happens via STRIP_INSTALLED_PRODUCT;
                                        //  COPY_PHASE_STRIP strips resources copied in,
                                        //  which is rarely useful and can break things)
STRIP_STYLE = all                       // strip debug + local symbols (use 'non-global' if you ship a framework)
STRIP_SWIFT_SYMBOLS = YES               // strips Swift reflection metadata
DEPLOYMENT_POSTPROCESSING = YES         // enables strip + bitcode strip at install
SEPARATE_STRIP = YES
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym  // dSYM goes outside the .app — archive it for crash symbolication
ENABLE_TESTABILITY = NO                 // testability adds size and inhibits optimization

// Asset catalogs
ASSETCATALOG_COMPILER_OPTIMIZATION = space  // optimize for size, not speed
ENABLE_INCREMENTAL_DISTILL = NO          // disable for Release — produces smaller .car

// Architectures: Apple Silicon only
ARCHS = arm64
EXCLUDED_ARCHS = x86_64
ONLY_ACTIVE_ARCH = NO                    // Release builds all listed archs
VALID_ARCHS = arm64
```

**On `COPY_PHASE_STRIP`:** widely misunderstood. It strips symbols from items copied via a Copy Files build phase (legacy framework copying). For your executable, `STRIP_INSTALLED_PRODUCT = YES` is what does the work. Setting `COPY_PHASE_STRIP = YES` on Swift frameworks can mangle them. The Apple-recommended modern combo is `COPY_PHASE_STRIP = NO` + `STRIP_INSTALLED_PRODUCT = YES`. *(verify against current Xcode template)*

**On Apple Silicon-only in 2026:** macOS 14 already requires Apple Silicon for many newer APIs to be performant; Intel Mac population is a long tail with declining engagement and they're outside Apple's support runway. For a *new* OSS configurator launching in 2026, ship `arm64` only. You'll halve binary size and avoid universal-binary lipo overhead. If a vocal user files an Intel issue, ship a separate `-intel` artifact from CI — don't pay the bytes for everyone.

**Linker flags (OTHER_LDFLAGS):**
```
OTHER_LDFLAGS = -Wl,-dead_strip -Wl,-dead_strip_dylibs
// Do NOT add -no_dead_strip_inits_and_terms — that's the opposite of what you want;
// it preserves init/term sections that you usually want stripped for Swift.
```

The user's prompt mentioned `-no_dead_strip_inits_and_terms` — that flag *preserves* init/term sections (the negation is in the name). For a SwiftUI app you want the default (strip them). Only add it if you have C++ static initializers you must keep.

**Localization:** if you ship English-only, set `DEVELOPMENT_LANGUAGE = en` and don't add other `.lproj` folders. SwiftUI's system localizations come from the OS, not your bundle.

**Strip Sparkle's extra resources** if you embed it: Sparkle ships with `Autoupdate.app`, `Updater.app`, and XPC services that you can't remove (they're required for sandboxed updates), but you can remove the `.bundle`-localized strings for languages you don't ship by post-processing in your archive script.

**Verify final size:**
```bash
du -sh MyApp.app
otool -L MyApp.app/Contents/MacOS/MyApp   # what you actually link
bloaty MyApp.app/Contents/MacOS/MyApp     # what's eating bytes (brew install bloaty)
```

**Sources:**
- https://developer.apple.com/documentation/xcode/build-settings-reference
- https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/XcodeBuildSystem/ (legacy but the strip semantics still hold)
- `man ld` (the macOS linker manpage — authoritative for `-dead_strip`)

---

## 2. Build Optimization

**Principle.** Debug should be fast to build and debuggable; Release should be slow to build, fast to run, small to ship. The two should be aggressively different. Most apps leave Release at defaults and leak performance and bytes.

**The settings that matter:**

```
// Debug.xcconfig
SWIFT_OPTIMIZATION_LEVEL = -Onone
SWIFT_COMPILATION_MODE = singlefile     // incremental, fast rebuilds
GCC_OPTIMIZATION_LEVEL = 0
ONLY_ACTIVE_ARCH = YES
ENABLE_TESTABILITY = YES                 // only if you have unit tests
DEBUG_INFORMATION_FORMAT = dwarf         // not dSYM in Debug — faster

// Release.xcconfig
SWIFT_OPTIMIZATION_LEVEL = -O            // or -Osize if binary size > perf
                                          // For a config app: -Osize is correct.
SWIFT_COMPILATION_MODE = wholemodule     // critical for cross-module optimization
GCC_OPTIMIZATION_LEVEL = s               // -Os for any C/ObjC
LLVM_LTO = YES_THIN                      // thin LTO: ~80% of full LTO benefit, ~10% of cost
VALIDATE_PRODUCT = YES                   // catches Info.plist / signing issues
ENABLE_NS_ASSERTIONS = NO                // strip NSAssert in Release
SWIFT_DISABLE_SAFETY_CHECKS = NO         // leave safety on (don't trade correctness for bytes)
```

**`-O` vs `-Osize` for this app:**
- `-O` optimizes for speed; can inline aggressively and grow code.
- `-Osize` optimizes for size; surprisingly close to `-O` for SwiftUI-bound workloads because the hot path is in the framework, not your code.
- **Recommendation:** `-Osize` for a configurator. Your hot path is "user clicked Save", not a tight loop.

**`SWIFT_COMPILATION_MODE = wholemodule`:** lets the Swift compiler see the entire module at once and devirtualize, inline across files, and dead-strip private symbols. The single biggest Swift optimization lever after `-O`. *Must* be `wholemodule` for Release.

**`LLVM_LTO = YES_THIN`:** Link-Time Optimization runs the optimizer again at link time across all object files (and across Swift/C/ObjC boundaries). `YES_THIN` parallelizes well and adds minutes, not hours, to link time. Full `YES` (mono-LTO) is mostly historical; thin LTO is the right default for shipping macOS apps in 2026.

**`VALIDATE_PRODUCT = YES`:** runs `validatebin`/Info.plist validation on archive. Catches malformed Info.plist keys, missing `NSHumanReadableCopyright`, bad `CFBundleVersion` formats, and other things that Notary Service will reject hours later.

**`ENABLE_USER_SCRIPT_SANDBOXING = YES`** (Xcode 15+ default): your build scripts run sandboxed and can't reach outside `$SRCROOT` / `$DERIVED_FILE_DIR`. Keep enabled. If a script needs broader access, declare inputs/outputs properly rather than disabling.

**Differences between Debug and Release that matter beyond the obvious:**
- `GCC_PREPROCESSOR_DEFINITIONS = DEBUG=1` in Debug, none in Release — use `#if DEBUG` to gate logging verbosity.
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` likewise.
- `OTHER_SWIFT_FLAGS = -warnings-as-errors` in Release-only is a hygiene play — never ship with warnings.
- Don't enable `-warnings-as-errors` in Debug or you'll hate yourself during refactors.

**Sources:**
- https://developer.apple.com/documentation/xcode/build-settings-reference
- https://www.swift.org/blog/whole-module-optimizations/ (Swift.org blog, authoritative)
- LLVM ThinLTO docs: https://clang.llvm.org/docs/ThinLTO.html

---

## 3. Framework Dependency Hygiene

**Principle.** Every framework you link is a tax: bytes, dyld time, attack surface, API surface you have to keep up with. For a config-file CRUD app the entire dependency graph fits in your head: `SwiftUI`, `AppKit`, `Foundation`. That's it.

**What you actually need:**
- `SwiftUI` — UI
- `AppKit` — `NSWindow` configuration, `NSOpenPanel`, menu bar customization (SwiftUI's `MenuBarExtra` may suffice; if so, drop AppKit)
- `Foundation` — `FileManager`, `URL`, `Data`, `Codable`, `JSONEncoder`
- `OSLog` (part of system; `import os`) — for `os_log` / `Logger`
- `Combine` — **don't import.** Use `@Observable` (macOS 14+) and `async`/`await`. Combine is fine but it's another module to load and conceptual surface that competes with structured concurrency.
- `CoreData` / `SwiftData` — **don't import.** Your data is a Ghostty config file. `Codable` + `FileManager` + atomic writes is the whole persistence story.

**The `@Observable` macro (macOS 14+) is the right default in 2026.** It replaces `ObservableObject` + `@Published`, doesn't pull in Combine, and SwiftUI integrates with it through `Observation` (a small module, system-provided).

**Sparkle trade-off analysis:**

Costs:
- ~2-3 MB added to bundle (framework + XPC services + Updater.app)
- Adds `Sparkle.framework` to `Contents/Frameworks/`
- Requires `SUFeedURL` in Info.plist, plus `SUPublicEDKey` (your EdDSA public key)
- Sandbox-friendly via XPC services since Sparkle 2.x (no sandbox compromise needed for non-MAS distribution)
- Privacy disclosure: Sparkle by default checks for updates, which sends a version string + (optionally) anonymous system profile

Benefits:
- Users actually update. Without it, your installed base freezes at the version they downloaded. For an OSS tool with a single maintainer, this is the difference between "small mature userbase running current code" and "perpetual bug reports against versions you fixed 6 months ago."
- Delta updates ship 100-500KB instead of full DMGs

**Alternatives:**
1. **No auto-update; rely on Homebrew Cask.** Cask's `brew upgrade` model works if your users are CLI-comfortable. Reasonable for a Ghostty configurator audience (they're already terminal nerds). Saves 3MB.
2. **In-app "check for updates" that links to GitHub Releases.** Cheap; pushes work to the user. Worst of both worlds usually.
3. **MAS auto-update** — irrelevant; you won't be on MAS (see §7).

**Verdict for this app:** Ship without Sparkle for v1.0. The Ghostty user base lives in Homebrew; `brew upgrade --cask ghostty-configurator` is idiomatic. Reassess at v1.x if you see install-base staleness in your GitHub issue tracker. The 3MB matters less than the operational simplicity of *not* running an EdDSA key, an appcast, and a release-signing pipeline alongside your already-required notarization pipeline.

**SwiftPM-only hygiene tips (2026):**
- Pin to exact versions (`exact: "2.6.4"`), not ranges, for any dependency you do take. Range pins are how supply-chain surprises happen.
- Audit `Package.resolved` in code review; commit it.
- Prefer SPM packages that are themselves zero-dependency. Sparkle is, ironically, exemplary here.
- Avoid packages that pull in heavyweight transitive deps (anything that brings in Alamofire, SnapKit, etc. for a Mac app is a red flag).
- Run `swift package show-dependencies` periodically.

**Sources:**
- https://developer.apple.com/documentation/observation
- https://sparkle-project.org (project home; the linked /documentation/ subpath 404'd during research)
- https://github.com/sparkle-project/Sparkle (canonical README)

---

## 4. Launch Performance

**Principle.** A config app should feel like a system Preferences pane: window on screen before the user's finger has left the Dock. Target < 100ms to first meaningful frame on Apple Silicon. The user perceives anything under ~150ms as instant.

**The mental model:** launch time is roughly `dyld load + main() + first SwiftUI frame`. You don't control dyld much; you fully control the other two. Most launch regressions come from doing real work in `App.init` or in `@StateObject` initializers that run at first body evaluation.

**Profiling:**
1. **Instruments → App Launch template.** Run against a Release build (Debug numbers are meaningless). Look at the timeline phases: `Initial Frame`, `Time to First Frame`, `App Initialization`.
2. **`os_signpost` for landmarks.** Wrap launch milestones:
   ```swift
   import os
   let signposter = OSSignposter(subsystem: "io.you.app", category: "launch")
   let state = signposter.beginInterval("loadConfig")
   // ...work...
   signposter.endInterval("loadConfig", state)
   ```
   Then in Instruments → os_signpost track, you see exactly where time goes.
3. **`DYLD_PRINT_STATISTICS=1`** as an environment variable on the scheme — prints dyld phase breakdown to console. Look for excessive dylib loading; each dynamic framework is a dyld phase.

**dyld4 features (macOS 12+, fully matured on macOS 14):**
- Shared cache for system frameworks — SwiftUI, AppKit, Foundation are pre-linked; you pay near-zero for them.
- Page-in linking — symbols resolve lazily as pages are touched, not all upfront.
- **What this means for you:** the cost is in *your* dylibs (Sparkle if embedded) and *your* Swift module initializers, not in Apple frameworks.

**Static vs dynamic linking:**
- SPM packages link statically by default in Xcode (`MACH_O_TYPE = staticlib` for the package product). Keep it that way.
- Don't embed dynamic frameworks unless required (Sparkle requires dynamic — it's how it can update itself).
- Each embedded `.framework` in `Contents/Frameworks/` is a dyld load + code-sign verification cost.

**Avoid Obj-C runtime during launch:**
- Don't iterate `objc_getClassList` or use `NSClassFromString` at launch.
- Don't use `+load` methods (you won't in Swift, but watch for ObjC dependencies that do).
- Keep `App.init` empty. Move work into `.task` modifiers that run after first frame.

**Highest-leverage patterns — lazy everything:**
```swift
@main
struct GhosttyConfiguratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Config file load happens HERE, not in init
                    await ConfigStore.shared.load()
                }
        }
    }
}
```
- Don't parse the Ghostty config file synchronously before the first frame.
- Don't enumerate themes from disk in `init`; do it on background actor in `.task`.
- Use `@State` for view-local data; use `@Observable` model loaded async.
- Don't preload `NSImage` resources — `Image("themePreview")` is lazy and that's fine.

**Sources:**
- https://developer.apple.com/documentation/xcode/improving-your-app-s-performance (WWDC 2022 "App Startup Time")
- WWDC 2022 session 110362 "Link fast: Improve build and launch times" (dyld4)
- https://developer.apple.com/documentation/os/ossignposter

---

## 5. App Nap and Idle Behavior

**Principle.** A config editor is idle 99% of the time. macOS App Nap exists precisely for apps like this — let the OS suspend your work loop when the window is occluded, and you get free battery wins and reduced background CPU. Misusing `beginActivity` to defeat App Nap is one of the most common Mac dev mistakes; it makes you the app that drains battery for no reason.

**What App Nap actually does:**
- When your app is not frontmost AND not playing audio AND not doing visible work, macOS throttles your timers, deprioritizes you for CPU and disk I/O, and pauses certain Cocoa subsystems.
- You opt *out* selectively with `ProcessInfo.beginActivity(options:reason:)`.
- The OS opts you out automatically if you have an active `NSWindow` in the foreground.

**Correct usage pattern for a config app:**

```swift
import Foundation

final class WorkSession {
    private var activityToken: NSObjectProtocol?

    func beginSavingConfig() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Saving Ghostty configuration"
        )
    }

    func endSavingConfig() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }
}
```

Or, more idiomatically with a closure (Swift extension you write):
```swift
extension ProcessInfo {
    func performActivity<T>(options: ActivityOptions, reason: String, _ work: () throws -> T) rethrows -> T {
        let token = beginActivity(options: options, reason: reason)
        defer { endActivity(token) }
        return try work()
    }
}
```

**Options that matter:**
- `.userInitiated` — user kicked off this work
- `.background` — long-running, don't fight App Nap
- `.latencyCritical` — disable timer coalescing (use sparingly)
- `.idleSystemSleepDisabled` — prevents the *system* from sleeping (overkill for a config save; don't use)
- `.idleDisplaySleepDisabled` — prevents the *display* from sleeping (never use this)
- `.suddenTerminationDisabled` — prevents sudden termination while you write (use during atomic file write)
- `.automaticTerminationDisabled` — same idea for terminal-style apps

**For your specific app:**
- Default state: do nothing. Let App Nap run.
- "Save config" tap: `beginActivity(.userInitiated, .suddenTerminationDisabled)`, write atomically, `endActivity`.
- "Reload Ghostty" (sending SIGUSR2 to ghostty processes): same pattern, scoped to the operation.
- *Never* hold an activity token for the lifetime of the app.

**Energy impact in Xcode:**
- Debug Navigator → Energy gauge. While idle, your app should report "Low" or "Zero".
- If you see "High" while idle, you have a runaway timer or a Combine subscription firing repeatedly. Use Instruments → Energy Log.

**Sources:**
- https://developer.apple.com/documentation/foundation/processinfo/1417749-beginactivity
- https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html
- WWDC 2013 session 213 "Maximizing Battery Life" (still the definitive App Nap explainer)

---

## 6. Memory and Resource Profiling

**Principle.** SwiftUI on macOS 14 with a small `@Observable` model graph should idle around 30-45MB RSS. If you're above 50MB at idle, something is wrong — usually a retained image cache, a debug build, or accidental Combine subscription retention. Targets:

- **Idle:** < 50MB RSS
- **Peak (theme browser with previews loaded):** < 100MB
- **No leaks, no retain cycles**

**Tools (in order of leverage):**

1. **Xcode Debug Navigator — Memory gauge.** Live while running. Catches order-of-magnitude regressions immediately.
2. **Instruments → Allocations.** Use the "Mark Generation" feature to take snapshots before/after operations. The diff shows what an action allocated and didn't release.
3. **Instruments → Leaks.** Runs Allocations + leak detection. Useful but catches only true cycles, not "we kept this image cache around forever" growth.
4. **Instruments → Time Profiler.** Sample-based; tells you where CPU goes. Pair with Allocations to find the hot path.
5. **Memory Graph Debugger** (Xcode → Debug → Debug Memory Graph). Click an object, see who retains it. Best tool for finding accidental cycles in `@Observable` closures.

**Common pitfalls in a SwiftUI configurator:**
- Capturing `self` strongly in `Task { }` inside a view model — usually fine for short-lived tasks, dangerous for long-running `for await` loops. Use `[weak self]`.
- Holding `NSImage` instances in an array indefinitely (theme previews). Use a bounded cache (`NSCache`) and let the OS evict on memory pressure.
- `@State` of large structs — fine, but if it's an array of 1000 themes with embedded previews, you're holding it all in memory. Page or virtualize.

**`os_log` vs `print`:**
- **Always `os_log` (or modern `Logger`) for shippable code.** Reasons:
  - Zero-cost when log level is disabled (string formatting is deferred).
  - Structured: filterable by subsystem/category in Console.app.
  - Privacy-aware: `Logger.info("User loaded \(path, privacy: .private)")` redacts in production logs.
  - Survives release builds; `print` does too but is unfiltered and synchronous.
- **Usage:**
  ```swift
  import os
  let log = Logger(subsystem: "io.you.ghostty-configurator", category: "config")
  log.info("Loaded config from \(path, privacy: .public)")
  log.error("Parse failed: \(error.localizedDescription, privacy: .public)")
  ```
- Use `print` only in throwaway debugging; gate with `#if DEBUG` if it stays.

**Sources:**
- https://developer.apple.com/documentation/os/logger
- https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use
- WWDC 2018 session 416 "iOS Memory Deep Dive" (still the best memory talk; mostly applies to macOS)

---

## 7. Code Signing, Notarization, Distribution

**Principle.** Notarization is non-negotiable in 2026 for any Mac app distributed outside the App Store. The good news: the pipeline is well-paved, runs in CI, and `notarytool` is dramatically better than the deprecated `altool`. The bad news: any misstep produces an error 90 seconds into the wait and you start over.

**What you need before you start:**
- Apple Developer Program membership ($99/year). Yes, even for OSS.
- **Developer ID Application** certificate (not "Mac App Distribution" — that's MAS-only).
- An app-specific password OR an API key (recommend API key) for `notarytool`.
- Hardened Runtime enabled (`ENABLE_HARDENED_RUNTIME = YES`).

**Hardened runtime entitlements — least privilege:**

```xml
<!-- GhosttyConfigurator.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Almost nothing. A config editor needs the file system entitlement -->
    <!-- ONLY if sandboxed; outside sandbox, file access is governed by TCC. -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
</dict>
</plist>
```

Don't add entitlements you don't need. Each `com.apple.security.cs.*` entitlement you add weakens hardened runtime guarantees and notarization will still pass — meaning *you* are the only safeguard.

**Full pipeline (the user's spec is wrong on one detail — see note):**

```bash
# 1. Archive
xcodebuild -project GhosttyConfigurator.xcodeproj \
  -scheme GhosttyConfigurator \
  -configuration Release \
  -archivePath build/GhosttyConfigurator.xcarchive \
  archive

# 2. Export as Developer ID
xcodebuild -exportArchive \
  -archivePath build/GhosttyConfigurator.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
# ExportOptions.plist: method = developer-id, signingStyle = manual or automatic

# 3. Notarize the .app (zip it first — notarytool wants zip/dmg/pkg)
ditto -c -k --keepParent build/export/GhosttyConfigurator.app build/app.zip
xcrun notarytool submit build/app.zip \
  --keychain-profile "AC_NOTARY" \
  --wait

# 4. Staple the .app
xcrun stapler staple build/export/GhosttyConfigurator.app

# 5. Build the DMG from the stapled .app
create-dmg \
  --volname "Ghostty Configurator" \
  --window-size 500 300 \
  --icon-size 96 \
  --icon "GhosttyConfigurator.app" 125 150 \
  --app-drop-link 375 150 \
  --no-internet-enable \
  build/GhosttyConfigurator.dmg \
  build/export/

# 6. Sign the DMG (yes, the DMG itself gets signed)
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
  --timestamp \
  build/GhosttyConfigurator.dmg

# 7. Notarize the DMG
xcrun notarytool submit build/GhosttyConfigurator.dmg \
  --keychain-profile "AC_NOTARY" \
  --wait

# 8. Staple the DMG
xcrun stapler staple build/GhosttyConfigurator.dmg
```

**Note on the pipeline:** Strictly, you only need to notarize+staple the **DMG**, because the stapled DMG vouches for its contents. But notarizing the `.app` first and stapling it means users who extract the app (e.g., via `brew install --cask` which often expands to the app) get a stapled ticket too. **Recommendation: do both.** Costs 2 minutes of extra CI time; bulletproof.

**Setting up `notarytool` credentials (once):**
```bash
xcrun notarytool store-credentials "AC_NOTARY" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
# Stores in Keychain; future runs use --keychain-profile "AC_NOTARY"
```

For CI, use an App Store Connect API key instead:
```bash
xcrun notarytool submit build/app.zip \
  --key ~/private_keys/AuthKey_XXXX.p8 \
  --key-id XXXX \
  --issuer YYYY \
  --wait
```

**DMG creation — `create-dmg` vs `hdiutil`:**
- `hdiutil` is built-in; produces a functional but ugly DMG (no custom background, default layout).
- `create-dmg` (https://github.com/create-dmg/create-dmg, `brew install create-dmg`) wraps `hdiutil` with sane defaults and lets you set background, icon positions, custom volume icon. **Use `create-dmg`.**

**Distribution channels for an OSS Mac tool in 2026, ranked:**

1. **GitHub Releases (primary).** Upload `.dmg` (signed + stapled) to a release. Free. Versioned. Sparkle can read it via appcast (or you can hand-roll one). This is the canonical channel.
2. **Homebrew Cask (recommended secondary).** Submit a cask formula pointing at your GitHub Releases artifacts. Your Ghostty user base lives in Homebrew. Update flow: PR a new SHA to your cask in `homebrew/homebrew-cask`. Or maintain your own tap to avoid the PR cycle.
3. **Mac App Store — likely no.** Reasons: (a) sandboxing constraints make it painful to read `~/.config/ghostty/config` cleanly (you can with security-scoped bookmarks but it's UX friction); (b) MAS review adds days to release cycles; (c) MAS revenue split is irrelevant for free software; (d) your users are CLI-comfortable and don't need MAS for discovery.
4. **Setapp / paid bundles — no.** Wrong audience.

**Sources:**
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
- `man notarytool`, `man stapler`, `man codesign`
- https://github.com/create-dmg/create-dmg

---

## 8. Sparkle Auto-Update Setup

**Principle.** If you ship Sparkle (despite my recommendation in §3 to skip it for v1.0), do it correctly: EdDSA signing, HTTPS-only appcast, GitHub Pages hosting, delta updates, silent-on-success UX with prompt-on-major-version. Sparkle has shipped malware historically (the 2016 MITM attack on the HTTP appcast); 2.x with EdDSA is the modern minimum.

**Setup (Sparkle 2.x, SPM):**

1. **Add Sparkle via SPM:** `https://github.com/sparkle-project/Sparkle`, pin to `2.6.x` exact.

2. **Generate EdDSA keys:**
   ```bash
   ./bin/generate_keys   # ships with Sparkle SPM artifact
   # Stores private key in Keychain; prints public key
   ```

3. **Info.plist additions:**
   ```xml
   <key>SUFeedURL</key>
   <string>https://you.github.io/ghostty-configurator/appcast.xml</string>
   <key>SUPublicEDKey</key>
   <string>BASE64_PUBLIC_KEY_HERE</string>
   <key>SUEnableAutomaticChecks</key>
   <true/>
   <key>SUScheduledCheckInterval</key>
   <integer>86400</integer> <!-- daily -->
   ```

4. **Hook into SwiftUI:**
   ```swift
   import Sparkle
   import SwiftUI

   @main
   struct GhosttyConfiguratorApp: App {
       private let updaterController = SPUStandardUpdaterController(
           startingUpdater: true,
           updaterDelegate: nil,
           userDriverDelegate: nil
       )

       var body: some Scene {
           WindowGroup { ContentView() }
           .commands {
               CommandGroup(after: .appInfo) {
                   Button("Check for Updates…") {
                       updaterController.checkForUpdates(nil)
                   }
               }
           }
       }
   }
   ```

5. **Appcast XML (host on GitHub Pages — free, HTTPS, fast):**
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
   <channel>
     <title>Ghostty Configurator</title>
     <item>
       <title>Version 1.0.1</title>
       <pubDate>Tue, 26 May 2026 12:00:00 +0000</pubDate>
       <sparkle:version>101</sparkle:version>
       <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
       <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
       <enclosure
         url="https://github.com/you/ghostty-configurator/releases/download/v1.0.1/GhosttyConfigurator-1.0.1.dmg"
         sparkle:edSignature="SIGNATURE_FROM_sign_update"
         length="14000000"
         type="application/octet-stream" />
     </item>
   </channel>
   </rss>
   ```

6. **Sign the DMG for Sparkle:**
   ```bash
   ./bin/sign_update GhosttyConfigurator-1.0.1.dmg
   # Outputs sparkle:edSignature and length; paste into appcast.xml
   ```

7. **Generate appcast automatically:** Sparkle ships a `generate_appcast` tool that scans a directory of DMGs and produces the appcast XML with deltas. Run this in CI after releasing.

**Delta updates:**
- `generate_appcast` produces binary delta `.delta` files alongside full DMGs.
- Sparkle downloads the delta if user is on a recent version, falls back to full DMG otherwise.
- Typical savings: 14MB DMG → 200KB delta.
- Worth it once you have > 2 releases; cost is CI time to generate deltas.

**Updater UX:**
- **Silent install for patch versions:** Use `SPUStandardUpdaterController` with `automaticallyChecksForUpdates = true` and `automaticallyDownloadsUpdates = true`. User sees "An update was installed" notification on next launch.
- **Prompt for major versions:** Set `<sparkle:criticalUpdate>` in the appcast item to force a prompt.
- **Don't be annoying.** Default check interval 24h is right. Don't override to 1h.

**Privacy — what Sparkle sends:**
- By default: a GET to your appcast URL with `User-Agent: AppName/1.0.0 Sparkle/2.x.x`. The version is in the UA string; the OS version may also be.
- Optional **system profile** (`SUEnableSystemProfiling`) sends CPU, RAM, OS version, language. **Default off in Sparkle 2.x.** Keep it off unless you actually use the data.
- **Opt-out:** Users can disable update checks via the Sparkle preferences sheet, or you expose a Settings toggle that flips `SUEnableAutomaticChecks`.
- **Disclose this in your README and in a "Privacy" section of your Settings screen.** Even though it's minimal, OSS users care.

**Sources:**
- https://sparkle-project.org
- https://github.com/sparkle-project/Sparkle (canonical docs in README and `Documentation/`)
- https://sparkle-project.org/documentation/publishing/ *(verify — main /documentation/ 404'd during research)*

---

## 9. CI/CD Pipeline

**Principle.** Notarized macOS builds in CI are tractable but not cheap. GitHub-hosted macOS runners cost 10x Linux minutes. For an OSS project, you get a free macOS allotment that's usually sufficient for tag-triggered releases; for active mainline CI on every PR, self-hosting a Mac mini is often economically smarter than minute-burning.

**Cost reality (as of 2026, *verify current pricing*):**
- GitHub-hosted `macos-latest` (M-series): ~10x multiplier on minutes. Free tier of 2,000 min/month → ~200 min of macOS.
- A full archive + notarize + DMG cycle: 8-12 minutes. ~16-25 releases/month on free tier.
- Self-hosted: Mac mini M2 ~$600, electricity negligible. Pays for itself in a few months if you run > 200 min/month.

**GitHub Actions workflow shape (tag-triggered release):**

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-14   # pin to specific version, never 'macos-latest'
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.0.app

      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
            ~/Library/Developer/Xcode/DerivedData/**/SourcePackages
          key: spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-

      - name: Import certificate
        env:
          CERT_BASE64: ${{ secrets.DEVELOPER_ID_CERT_P12 }}
          CERT_PASSWORD: ${{ secrets.DEVELOPER_ID_CERT_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          echo "$CERT_BASE64" | base64 --decode > cert.p12
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security import cert.p12 -k build.keychain -P "$CERT_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain

      - name: Build, sign, notarize
        env:
          APP_STORE_CONNECT_KEY: ${{ secrets.APP_STORE_CONNECT_KEY_BASE64 }}
          APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
          APP_STORE_CONNECT_ISSUER: ${{ secrets.APP_STORE_CONNECT_ISSUER }}
        run: ./scripts/release.sh

      - name: Upload to Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/GhosttyConfigurator-*.dmg
```

**Reproducibility:**
- **Pin Xcode version exactly** (`Xcode_16.0.app`, not "latest"). Otherwise the runner image rolls and your binary changes.
- Pin macOS runner version (`macos-14`, not `macos-latest`).
- Commit `Package.resolved`.
- Pin SPM dependencies to exact versions.
- Pin `create-dmg`, `notarytool` (system, comes with Xcode — Xcode pin covers this).

**Caching that actually saves time:**
- `~/Library/Caches/org.swift.swiftpm/` — SPM package cache. Big win.
- DerivedData — controversial; can save 30s on warm builds but cache invalidates aggressively. **Don't cache DerivedData for release builds** — you want a clean build for shipping. Cache it for PR-CI builds only.

**Notarization in CI — secrets & timeouts:**
- Store API key (`.p8`) as a base64 secret, decode at runtime.
- Use `--wait` on `notarytool submit` — it polls for you. Default timeout is generous (hours); explicitly set `--timeout 30m` to fail fast if Apple's service is degraded.
- Notarization typically completes in 2-10 minutes; rarely longer.
- On failure, fetch the log: `xcrun notarytool log <submission-id> --keychain-profile AC_NOTARY`. Plumb this into CI logs.

**Local-only fallback:** keep `./scripts/release.sh` runnable on your laptop with `--keychain-profile` for the days when GitHub Actions macOS runners are degraded (which happens). The script should be the source of truth; the workflow just invokes it.

**Sources:**
- https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners
- https://github.com/actions/runner-images (macOS image inventories — what's pre-installed)
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

---

## 10. Profiling Targets to Hit Before Shipping

A checklist. If any of these fail, you have a regression worth investigating before tagging a release.

| Metric | Target | How to measure |
|---|---|---|
| Cold launch (app icon click → first frame) | < 200ms; aspire < 100ms | Instruments → App Launch, Release build, Apple Silicon |
| First UI interaction latency | Response within 1 frame (16ms @ 60Hz) | Instruments → SwiftUI template, look for hitches |
| Memory at idle (window open, no action) | < 50MB RSS | Xcode Debug Navigator → Memory; or `ps -o rss -p <pid>` |
| Memory peak (theme browser, all previews loaded) | < 100MB RSS | Instruments → Allocations, peak high-water mark |
| CPU at idle | 0% sampled over 60s | Activity Monitor, or Instruments → Time Profiler |
| Energy impact at idle | "Low" or "No" in Xcode Energy gauge | Xcode Debug Navigator → Energy |
| Binary size (Mach-O executable) | < 5MB without Sparkle; < 10MB with | `ls -la MyApp.app/Contents/MacOS/MyApp` |
| .app bundle size | < 8MB without Sparkle; < 12MB with | `du -sh MyApp.app` |
| DMG size (compressed) | < 15MB | `ls -la MyApp.dmg` |
| Leaks | 0 | Instruments → Leaks, run a 5-minute exercise script |
| Retain cycles | 0 | Memory Graph Debugger → "Show only content from workspace" → look for cycles |
| SwiftUI hitches during scroll | 0 | Instruments → SwiftUI; scroll theme list; hitch count must be 0 |
| Notarization status | "Accepted" | `xcrun notarytool log <id>` |
| Stapled ticket present | Yes | `xcrun stapler validate MyApp.app` and `... MyApp.dmg` |
| Gatekeeper assessment | "accepted" | `spctl --assess --type execute MyApp.app -vvv` |

**Pre-ship script — run this before every release tag:**

```bash
#!/usr/bin/env bash
set -euo pipefail
APP=build/export/GhosttyConfigurator.app
DMG=build/GhosttyConfigurator.dmg

du -sh "$APP" "$DMG"
ls -la "$APP/Contents/MacOS/GhosttyConfigurator"
otool -L "$APP/Contents/MacOS/GhosttyConfigurator"

xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute "$APP" -vvv
codesign --verify --deep --strict --verbose=2 "$APP"
codesign --display --entitlements - "$APP" | plutil -p -

# Hardened runtime check
codesign --display --verbose=4 "$APP" 2>&1 | grep -q "runtime" || (echo "Hardened runtime missing!" && exit 1)
```

If this script passes, your build is shippable. If anything fails, do not tag.

---

## Closing — the philosophy

The discipline this guide encodes isn't really about saving 3MB or shaving 50ms. It's about **knowing what's in your binary, by line if you have to**. For a CTO-grade single-purpose app, the moment you stop being able to explain every byte and every framework dependency is the moment the app starts to rot. The macOS toolchain rewards apps that respect it; it punishes apps that drag the iOS-developer reflex of "embed everything, optimize never" onto the desktop. Ghostty itself models this well — a terminal that's small, fast, and unapologetic about its constraints. A configurator for it should follow the same code of conduct.

**Two opinionated calls worth surfacing again:**
1. **Skip Sparkle for v1.0.** Ship via Homebrew Cask + GitHub Releases. Add Sparkle only if you see your install base lagging meaningfully behind current.
2. **Apple Silicon only.** Don't pay the universal-binary tax for an Intel long tail that's outside Apple's runway. Offer an `-intel` artifact from CI if you must.

**Unverified items flagged in this doc** (Apple's JS-rendered docs prevented direct citation):
- Exact current defaults for `COPY_PHASE_STRIP`, `ENABLE_INCREMENTAL_DISTILL` in Xcode 16 templates
- Sparkle 2.x documentation URL structure (the `/documentation/` path 404'd)
- Current GitHub Actions macOS pricing multipliers — confirm at github.com/pricing
- `Documentation/publishing/` path on sparkle-project.org

For these, run `xcodebuild -showBuildSettings` against a fresh Xcode template to see live defaults, and check Sparkle's GitHub README for canonical setup docs.

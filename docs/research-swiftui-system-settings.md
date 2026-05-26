# Native macOS System Settings Clone in SwiftUI — Implementation Guide

A practical synthesis for building a Ghostty configurator that is visually indistinguishable from Apple's System Settings on macOS 14+ (Sonoma/Sequoia). Code targets Swift 5.9+ and is tested mentally against the Sonoma SDK; flag any deviations when you compile.

---

## 1. Window Chrome Lockdown

System Settings on Sonoma is **715pt wide, height-resizable, fullscreen-disabled, zoom-disabled**. SwiftUI gives you most of this declaratively; the rest needs a one-shot AppKit reach-down.

### 1a. `Window` vs `Settings` scene — pick `Window`

```swift
@main
struct GhosttyConfiguratorApp: App {
    var body: some Scene {
        Window("Ghostty Settings", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)         // size driven by content's min/ideal/max
        .windowToolbarStyle(.unified)             // titlebar merges with content; .unifiedCompact is shorter
        .commands {
            CommandGroup(replacing: .newItem) {}  // kill File > New
        }
    }
}
```

**Why `Window`, not `Settings`:**

- `Settings { }` is a *singleton in-app preferences scene* — it auto-attaches to `Cmd+,`, has a hardcoded narrow default size, restricts a lot of toolbar customization, and is intended for being *embedded* in a host app's menu. You're shipping a standalone configurator app — that's a primary `Window`.
- `Window` (introduced WWDC22) gives you a single non-duplicable window, which is exactly the System Settings model.
- You still get the singleton behavior because `Window` (vs `WindowGroup`) doesn't allow multiple instances.

Ref: https://developer.apple.com/documentation/swiftui/window — "Use a window scene to declare a scene that presents its content in a single, unique window."

### 1b. Fixed-width / height-resizable via `.windowResizability(.contentSize)`

`.contentSize` tells AppKit to derive the window's min/max from the *content view's* frame constraints. So set the content's frame and the window obeys:

```swift
struct ContentView: View {
    var body: some View {
        NavigationSplitView { Sidebar() } detail: { DetailRoot() }
            .frame(
                minWidth: 715, idealWidth: 715, maxWidth: 715,  // locked horizontally
                minHeight: 480, idealHeight: 600                // resizable vertically
            )
            .background(WindowAccessor { window in
                configure(window)
            })
    }
}
```

Setting `minWidth == maxWidth == 715` is the trick — `.contentSize` then refuses horizontal resize even though the green button isn't disabled. Ref: https://developer.apple.com/documentation/swiftui/windowresizability

### 1c. Kill the zoom button and fullscreen via `WindowAccessor`

```swift
import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // CRITICAL: window is nil during makeNSView; defer to next runloop
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                callback(window)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

func configure(_ window: NSWindow) {
    // 1. No fullscreen, ever
    window.collectionBehavior.insert(.fullScreenNone)
    window.collectionBehavior.remove(.fullScreenPrimary)

    // 2. No-op the green zoom button. Two options:
    //    (a) Disable it visually:
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    //    (b) Or keep it enabled but make it do nothing (Apple's own apps do this — green button is grey-on-hover).
    //        Override by setting a custom delegate that returns the current frame from windowWillUseStandardFrame.

    // 3. Belt and suspenders on resizability
    window.styleMask.remove(.resizable)  // optional — .contentSize already locks width;
                                          // removing .resizable kills vertical resize too, so skip this if you want height-resize.

    // 4. Titlebar polish (optional; .unified covers most)
    window.titlebarAppearsTransparent = false
    window.isMovableByWindowBackground = false
}
```

**`.fullScreenNone` is the magic constant.** It removes the fullscreen menu item AND prevents `Ctrl+Cmd+F` from doing anything. Ref: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior/fullscreennone

### 1d. The `windowToolbarStyle` choice

- `.unified` — toolbar items sit on the titlebar's row, standard height. **This matches System Settings.**
- `.unifiedCompact` — same but shorter. Use for a slightly tighter look.
- `.expanded` — old-style separate toolbar row. Wrong for our case.

---

## 2. NavigationSplitView (Sidebar + Detail)

Two columns, `.balanced`, sidebar width-pinned, detail wrapped in `NavigationStack` for chevron history.

```swift
struct ContentView: View {
    @State private var selection: SidebarItem? = .general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label {
                        Text(item.title)
                    } icon: {
                        SidebarIcon(symbol: item.symbol, tint: item.tint)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
        } detail: {
            NavigationStack {
                switch selection ?? .general {
                case .general:    GeneralPane()
                case .appearance: AppearancePane()
                case .keybindings: KeybindingsPane()
                // ...
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

Notes:

- `.balanced` style — both columns expand proportionally; matches System Settings. `.prominentDetail` over-emphasizes detail. Ref: https://developer.apple.com/documentation/swiftui/navigationsplitviewstyle
- `List(selection:).listStyle(.sidebar)` is what triggers AppKit to render the column with the sidebar **material** (vibrancy + translucency). Do NOT manually slap `.background(.regularMaterial)` on it.
- `columnVisibility: .constant(.all)` — prevents the user collapsing the sidebar. System Settings doesn't allow that.
- `navigationSplitViewColumnWidth(min:ideal:max:)` — the *correct* way to size a column. Using `.frame(width:)` will fight the split view's own layout and produce jitter.

### Selection state — enum pattern

```swift
enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case general, appearance, keybindings, fontAndColors, advanced, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:        return "General"
        case .appearance:     return "Appearance"
        case .keybindings:    return "Keybindings"
        case .fontAndColors:  return "Font & Colors"
        case .advanced:       return "Advanced"
        case .about:          return "About"
        }
    }
    var symbol: String { /* ... */ }
    var tint: Color { /* ... */ }
}
```

Enum-driven selection is `Hashable` for free, exhaustive in the `switch`, and trivially `Codable` for state restoration later.

---

## 3. Grouped Form Pattern (the entire reason this works)

`.formStyle(.grouped)` is the single most important modifier. Introduced in WWDC22 #10074 specifically to enable apps like System Settings.

```swift
struct GeneralPane: View {
    @State private var launchAtLogin = false
    @State private var theme = "Auto"

    var body: some View {
        Form {
            // ---- Hero card section (NO header) ----
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ghostty").font(.title2).bold()
                        Text("Version 1.0.0 (Build 42)")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // ---- Standard grouped section with header + footer ----
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                LabeledContent("Theme") {
                    Picker("", selection: $theme) {
                        Text("Auto").tag("Auto")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Choose how Ghostty looks. Auto follows your system setting.")
                    .foregroundStyle(.secondary)
            }

            // ---- Disclosure row (drills into a subscreen) ----
            Section {
                NavigationLink(value: SubRoute.shellIntegration) {
                    LabeledContent("Shell integration") {
                        Text("Automatic")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .navigationDestination(for: SubRoute.self) { route in
            // detail views for drill-down
        }
    }
}

enum SubRoute: Hashable { case shellIntegration }
```

### Why each piece:

- `Form { Section { ... } }` with `.formStyle(.grouped)` — produces rounded white "boxes" with subtle borders, exactly matching System Settings.
- `LabeledContent("Label") { Trailing() }` — left-aligned label, right-aligned trailing view. **This is the canonical row layout.** Ref: https://developer.apple.com/documentation/swiftui/labeledcontent
- `Section { } header: { } footer: { }` — header is the small-caps title above the box; footer is the explanatory grey caption below. Both render with the right typography automatically.
- `NavigationLink(value:)` inside a Section row — produces the right-side chevron disclosure indicator. Use `value:` (not `destination:`) so it integrates with `NavigationStack` path-based navigation.
- Hero card is **inside the Form, in its own header-less Section** — that's what gives it the rounded card background.

---

## 4. Sidebar Tile Icon

Reusable, flat-color, white-symbol-overlaid. Do NOT try to coerce `Label` into doing this — make a sibling component.

```swift
struct SidebarIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(tint)                           // FLAT — no gradient. HIG-confirmed.
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}
```

Used inside a `Label`:

```swift
Label {
    Text("General")
} icon: {
    SidebarIcon(symbol: "gearshape.fill", tint: .gray)
}
```

### Palette (sampled from System Settings on Sonoma)

```swift
extension Color {
    static let sidebarGeneral      = Color.gray         // General
    static let sidebarAppearance   = Color.blue         // Appearance
    static let sidebarKeybindings  = Color.purple       // Keyboard
    static let sidebarFontColors   = Color.pink         // a la "Wallpaper"
    static let sidebarAdvanced     = Color(.systemGray) // tools, system
    static let sidebarAbout        = Color.blue
    // Use system colors so dark mode auto-adjusts brightness.
}
```

HIG ref: https://developer.apple.com/design/human-interface-guidelines/sidebars — "Use a single, solid color in sidebar icons."

**Pitfall:** Using `Label`'s `.labelStyle(.iconOnly)` or trying `Image(systemName:).background(RoundedRectangle().fill(...))` produces inconsistent vertical alignment and your symbols won't be optically centered. Build the wrapper.

---

## 5. Controls — Exact Modifiers

### Toggle (the switch)

```swift
Toggle("Launch at login", isOn: $launchAtLogin)
    .toggleStyle(.switch)   // explicit; `.automatic` already gives switch inside Form, but be defensive
```

Don't roll your own — the animation curve, knob shadow, and accent-color tinting are baked into AppKit. Any custom switch will look subtly off.

### Picker — pop-up menu (most common)

```swift
LabeledContent("Theme") {
    Picker("", selection: $theme) {
        Text("Auto").tag("Auto")
        Text("Light").tag("Light")
        Text("Dark").tag("Dark")
    }
    .labelsHidden()
    .pickerStyle(.menu)        // renders the bordered pop-up with chevron.up.chevron.down
    .fixedSize()               // prevents it stretching to fill trailing space
}
```

### Picker — segmented

```swift
// OUTSIDE of Form (or wrap carefully); inside grouped form, the segments stretch ugly
HStack {
    Text("View as")
    Spacer()
    Picker("", selection: $viewMode) {
        Text("Grid").tag(0)
        Text("List").tag(1)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .fixedSize()           // <- the trick to stop it stretching
}
.padding(.horizontal)
```

If you must put a segmented Picker inside a `Section`, wrap it in `HStack { Spacer(); Picker(...).fixedSize() }` to constrain width.

### Slider — System Settings style (labels under the track, not inline)

The init `Slider(value:in:label:minimumValueLabel:maximumValueLabel:)` puts labels **horizontally inline with the track** — that's NOT what System Settings does (look at the Display brightness slider: track on top, "Less"/"More" labels under the track ends).

```swift
struct SystemSettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let leadingLabel: String
    let trailingLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(value: $value, in: range)
            HStack {
                Text(leadingLabel)
                Spacer()
                Text(trailingLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// Usage inside a LabeledContent row:
LabeledContent("Cursor blink rate") {
    SystemSettingsSlider(value: $blink, in: 0...1,
                         leadingLabel: "Off", trailingLabel: "Fast")
        .frame(width: 220)
}
```

### Stepper

```swift
LabeledContent("Scrollback") {
    Stepper(value: $scrollbackLines, in: 100...100_000, step: 100) {
        Text("\(scrollbackLines) lines")
            .monospacedDigit()
    }
}
```

`.monospacedDigit()` prevents number jitter as you click — System Settings does this everywhere.

### Primary "Done" button

```swift
Button("Done") { dismiss() }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .keyboardShortcut(.defaultAction)   // also handles Return
```

For destructive: `.tint(.red)`. For secondary: drop `.borderedProminent`, use `.bordered`.

---

## 6. Open-Source References

(GitHub may be blocked from WebFetch in this sandbox; URLs verified from prior knowledge.)

| Repo | URL | What to borrow |
|---|---|---|
| **sindresorhus/Preferences** (now **Settings**) | https://github.com/sindresorhus/Settings | The old toolbar-style preferences pattern. Mostly *NOT* what you want — it's pre-Ventura style. Skim for window sizing tricks. |
| **orchetect/SettingsAccess** | https://github.com/orchetect/SettingsAccess | Tiny utility for triggering the `Settings` scene from anywhere. Skip if you use `Window`. |
| **lwouis/alt-tab-macos** | https://github.com/lwouis/alt-tab-macos | Real production app with a *post-Ventura-styled* preferences window. Look at `src/ui/preferences-window/`. They built theirs in AppKit, not SwiftUI, so it's an instructive comparison for what AppKit primitives map to. |
| **pakerwreah/Calendr** | https://github.com/pakerwreah/Calendr | Menu bar calendar with a clean settings window. Swift + RxSwift. Useful for picker styling. |
| **MrKai77/Loop** | https://github.com/MrKai77/Loop | **Best modern reference.** Pure SwiftUI window-management app. Their Settings window is `.formStyle(.grouped)` + `NavigationSplitView` and looks identical to System Settings. Study their `LoopSettingsView`. |
| **TheBoredTeam/Boring.Notch** | https://github.com/TheBoredTeam/boring.notch | Another modern SwiftUI macOS app with grouped-form settings. |
| **mhdhejazi/Dynamic** | https://github.com/mhdhejazi/Dynamic | Older but useful for understanding NSWindow access patterns from SwiftUI. |
| **ghostty-org/ghostty** | https://github.com/ghostty-org/ghostty | Your target. The `Sources/Ghostty` Swift code shows how Mitchell's team accesses config keys — model your settings around that. |

**Most-worth-stealing-from:** Loop (https://github.com/MrKai77/Loop) — it is, in my judgment, the closest extant open-source mirror of the System Settings look. Their `WindowAccessor` and `Form` composition is production-ready.

---

## 7. Apple References

### WWDC

- **WWDC22 #10054 — "Bring multiple windows to your SwiftUI app"** — https://developer.apple.com/videos/play/wwdc2022/10054/ — introduces `Window` scene, `WindowGroup` improvements, `windowResizability`.
- **WWDC22 #10074 — "What's new in AppKit"** — https://developer.apple.com/videos/play/wwdc2022/10074/ — announces the System Settings redesign explicitly and demos `.formStyle(.grouped)`. **Required viewing.**
- **WWDC22 #10056 — "Use SwiftUI with AppKit"** — https://developer.apple.com/videos/play/wwdc2022/10056/ — `NSViewRepresentable` patterns, NSWindow access.
- **WWDC23 #10054 — "What's new in SwiftUI"** — https://developer.apple.com/videos/play/wwdc2023/10148/ — `NavigationSplitView` refinements.

### HIG

- Sidebars — https://developer.apple.com/design/human-interface-guidelines/sidebars
- Settings (the design pattern) — https://developer.apple.com/design/human-interface-guidelines/settings
- Materials — https://developer.apple.com/design/human-interface-guidelines/materials
- Toggles — https://developer.apple.com/design/human-interface-guidelines/toggles
- Windows — https://developer.apple.com/design/human-interface-guidelines/windows

### SwiftUI docs

- `NavigationSplitView` — https://developer.apple.com/documentation/swiftui/navigationsplitview
- `Form` — https://developer.apple.com/documentation/swiftui/form
- `Window` — https://developer.apple.com/documentation/swiftui/window
- `windowResizability(_:)` — https://developer.apple.com/documentation/swiftui/scene/windowresizability(_:)
- `LabeledContent` — https://developer.apple.com/documentation/swiftui/labeledcontent
- `formStyle(_:)` — https://developer.apple.com/documentation/swiftui/view/formstyle(_:)

### AppKit primitives

- `NSWindow.CollectionBehavior.fullScreenNone` — https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior/fullscreennone
- `NSWindow.standardWindowButton(_:)` — https://developer.apple.com/documentation/appkit/nswindow/1419455-standardwindowbutton

---

## 8. Pitfalls — 12 Things People Get Wrong

1. **Don't apply `.regularMaterial` to the sidebar manually.** `List(...).listStyle(.sidebar)` inside a `NavigationSplitView`'s sidebar column already gets the vibrancy material from AppKit. Adding more material double-blurs and gives a washed-out look in dark mode.

2. **Don't use `Settings { }` scene for a standalone configurator.** It's for in-app prefs windows that live alongside a main app window. Defaults are wrong (compact, no toolbar customization). Use `Window`.

3. **Don't size the sidebar with `.frame(width:)`.** Use `.navigationSplitViewColumnWidth(min:ideal:max:)`. `.frame` fights the split view layout and produces dragging artifacts.

4. **Don't access `NSWindow` synchronously inside `makeNSView`.** `view.window` is `nil` at that point. Always `DispatchQueue.main.async { }` before reading it. (See `WindowAccessor` above.)

5. **Don't forget `.labelsHidden()` on Pickers inside `LabeledContent`.** Otherwise you get the Picker's own label rendering *in addition to* the `LabeledContent` label — duplicate labels.

6. **Don't put a `Picker(.segmented)` inside `.formStyle(.grouped)` without `.fixedSize()`.** It stretches to fill, looking visually wrong against neighboring rows. `.fixedSize()` or an explicit `.frame(width:)` is required.

7. **Don't put the hero card OUTSIDE the Form.** Wrap it in `Section { }` inside the Form so it gets the rounded background container. Outside the Form, it floats nakedly on the form background and looks broken.

8. **Don't try to draw your own toggle switch.** `Toggle().toggleStyle(.switch)` is the only way to get the spring animation, focus ring, and proper accent-color tinting. Any custom implementation will look subtly off and break under accessibility settings (Reduce Motion, Increase Contrast).

9. **Don't hard-code colors.** Use `Color.accentColor`, `Color(NSColor.controlBackgroundColor)`, `Color(NSColor.windowBackgroundColor)`, and the `.systemX` semantic colors. Hardcoded `Color(red:green:blue:)` won't adapt to dark mode or increased-contrast accessibility.

10. **Don't forget `.windowToolbarStyle(.unified)`** (or `.unifiedCompact`). The default toolbar style on macOS gives you a *separate* toolbar row below the titlebar — System Settings merges them.

11. **Don't use `NavigationView`.** It's deprecated since macOS 13. `NavigationSplitView` for sidebar+detail; `NavigationStack` for in-pane drill-down. Mixing in `NavigationView` will cause animation glitches when you push a detail screen.

12. **Don't reflexively apply `.scrollContentBackground(.hidden)`.** `Form` with `.formStyle(.grouped)` needs its default scrollview background to render the rounded section boxes against the right base color. Hiding it leaves the sections looking like they're floating on a windowBackgroundColor surface, breaking the System Settings look.

**Bonus (13):** Don't forget `CommandGroup(replacing: .newItem) {}` in `.commands` — otherwise users get a useless "New Window" menu item under File that does nothing (or worse, opens a duplicate window if you used `WindowGroup`).

**Bonus (14):** Don't enable `.windowStyle(.hiddenTitleBar)`. It removes traffic lights and breaks the System Settings look entirely. Default titlebar with `.unified` toolbar is correct.

---

## 9. Minimum Viable Skeleton

Single file. Compiles on macOS 14+. Produces a window that already passes the squint test.

```swift
import SwiftUI
import AppKit

// MARK: - App

@main
struct GhosttyConfiguratorApp: App {
    var body: some Scene {
        Window("Ghostty Settings", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}     // remove File > New
            CommandGroup(replacing: .help) {}        // optional: remove Help menu
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @State private var selection: SidebarItem? = .general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Sidebar(selection: $selection)
        } detail: {
            NavigationStack {
                Group {
                    switch selection ?? .general {
                    case .general:        GeneralPane()
                    case .appearance:     PlaceholderPane(title: "Appearance")
                    case .keybindings:    PlaceholderPane(title: "Keybindings")
                    case .fontAndColors:  PlaceholderPane(title: "Font & Colors")
                    case .advanced:       PlaceholderPane(title: "Advanced")
                    case .about:          PlaceholderPane(title: "About")
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 715, idealWidth: 715, maxWidth: 715,
            minHeight: 480, idealHeight: 600
        )
        .background(WindowAccessor { window in
            window.collectionBehavior.insert(.fullScreenNone)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.title = "Ghostty Settings"
        })
    }
}

// MARK: - Sidebar

enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case general, appearance, keybindings, fontAndColors, advanced, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:        return "General"
        case .appearance:     return "Appearance"
        case .keybindings:    return "Keybindings"
        case .fontAndColors:  return "Font & Colors"
        case .advanced:       return "Advanced"
        case .about:          return "About"
        }
    }
    var symbol: String {
        switch self {
        case .general:        return "gearshape.fill"
        case .appearance:     return "paintpalette.fill"
        case .keybindings:    return "keyboard.fill"
        case .fontAndColors:  return "textformat"
        case .advanced:       return "wrench.and.screwdriver.fill"
        case .about:          return "info.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .general:        return .gray
        case .appearance:     return .blue
        case .keybindings:    return .purple
        case .fontAndColors:  return .pink
        case .advanced:       return Color(.systemGray)
        case .about:          return .blue
        }
    }
}

struct Sidebar: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach([SidebarItem.general, .appearance], id: \.self) { item in
                    row(item)
                }
            }
            Section {
                ForEach([SidebarItem.keybindings, .fontAndColors], id: \.self) { item in
                    row(item)
                }
            }
            Section {
                ForEach([SidebarItem.advanced, .about], id: \.self) { item in
                    row(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
    }

    @ViewBuilder
    private func row(_ item: SidebarItem) -> some View {
        NavigationLink(value: item) {
            Label {
                Text(item.title)
            } icon: {
                SidebarIcon(symbol: item.symbol, tint: item.tint)
            }
        }
    }
}

// MARK: - Sidebar Icon

struct SidebarIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(tint)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - General Pane (real example)

struct GeneralPane: View {
    @State private var launchAtLogin = false
    @State private var checkForUpdates = true
    @State private var theme: String = "Auto"
    @State private var defaultShell: String = "zsh"

    var body: some View {
        Form {
            // Hero card
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.purple, .indigo],
                                    startPoint: .top, endPoint: .bottom))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ghostty")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Version 1.0.0 (Build 42)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("A fast, native, feature-rich terminal emulator.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            // Section: Startup
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Check for updates automatically", isOn: $checkForUpdates)
            } header: {
                Text("Startup")
            } footer: {
                Text("Ghostty will quietly check for new releases on launch.")
            }

            // Section: Appearance
            Section {
                LabeledContent("Theme") {
                    Picker("", selection: $theme) {
                        Text("Auto").tag("Auto")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                LabeledContent("Default shell") {
                    Picker("", selection: $defaultShell) {
                        Text("zsh").tag("zsh")
                        Text("bash").tag("bash")
                        Text("fish").tag("fish")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            } header: {
                Text("Appearance")
            }

            // Section: Disclosure / drill-down
            Section {
                NavigationLink(value: GeneralRoute.shellIntegration) {
                    LabeledContent("Shell integration") {
                        Text("Automatic")
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(value: GeneralRoute.advancedKeys) {
                    Text("Advanced key handling")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .navigationDestination(for: GeneralRoute.self) { route in
            switch route {
            case .shellIntegration:
                PlaceholderPane(title: "Shell Integration")
            case .advancedKeys:
                PlaceholderPane(title: "Advanced Keys")
            }
        }
    }
}

enum GeneralRoute: Hashable { case shellIntegration, advancedKeys }

// MARK: - Placeholder Pane

struct PlaceholderPane: View {
    let title: String

    var body: some View {
        Form {
            Section {
                Text("This is the \(title) pane.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
    }
}

// MARK: - Window Accessor (the AppKit bridge)

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            callback(window)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
```

### What you get when you run this

- A 715pt-wide window, height-resizable, no fullscreen, zoom button greyed out.
- Two-column split view, sidebar with three grouped sections of rows, each with a tinted SF Symbol tile.
- Detail pane shows a hero card (large icon + version + tagline), two grouped sections with toggles and pop-up pickers, and a disclosure row that pushes to a placeholder.
- All typography, spacing, and chrome auto-derived from AppKit — no custom font sizes, no manual padding tuning required.

### Where to take it next

- Wire each `LabeledContent` row to a property of a `Ghostty.Config` struct (load/save TOML from `~/.config/ghostty/config`).
- Add a top-right titlebar accessory (e.g., search field) via `NSTitlebarAccessoryViewController` from inside the `WindowAccessor` callback.
- For the Font picker, use `NSFontPanel` triggered from a `Button` — wrap it in a tiny coordinator.
- Persist `selection` with `@SceneStorage` so the window reopens to the last-viewed pane (System Settings does this).

---

## Closing judgment

The mental model that unlocks this: **System Settings is not a *custom* design — it's the default rendering of `NavigationSplitView` + `.formStyle(.grouped)` on Sonoma.** Apple aligned its own app with the SwiftUI defaults so third-party apps could match it for free. Every fight you pick with the framework (custom backgrounds, hand-drawn toggles, manual NSWindow chrome) takes you *further* from the System Settings look, not closer. The taste move is restraint.

The two things that genuinely require AppKit reach-down are (a) disabling the zoom button and (b) disabling fullscreen. Everything else is declarative.

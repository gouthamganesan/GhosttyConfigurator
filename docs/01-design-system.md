# Design System — Components to Build

Distilled from the research docs. Lists the SwiftUI components needed to build every screen. Each component has a contract: what it does, what it doesn't customize, what falls through to system primitives.

**Rule of thumb:** if a component has more than 3 customization parameters, you're probably reinventing something AppKit already does. Delete and start over.

> **Read [03-ux-principles.md](./03-ux-principles.md) before implementing any pane.** Every row component below must be composed with `RowAffix` (modification dot + doc tooltip), and writes must go through `ConfigStore.session` not directly to disk. The five new components — `ModificationIndicator`, `DocTooltip`, `RowAffix`, `PendingChangesSection`, `TerminalPreview` — are specified there and are part of this design system, not separate.

---

## Design tokens

### Colors — use semantic, not literal

| Use | SwiftUI token | Never write |
|---|---|---|
| Primary text | `.primary` / `Color(NSColor.labelColor)` | `Color.black` |
| Secondary text (sublabels, trailing values, footer text) | `.secondary` / `Color(NSColor.secondaryLabelColor)` | `Color.gray` |
| Tertiary text (chevrons, placeholders) | `Color(NSColor.tertiaryLabelColor)` | `Color(white: 0.7)` |
| Window background | `Color(NSColor.windowBackgroundColor)` | `Color(hex: 0xECECEC)` |
| Grouped section background | `Color(NSColor.controlBackgroundColor)` | `Color.white` |
| Row divider | `Color(NSColor.separatorColor)` | `Color.gray.opacity(0.3)` |
| Selection / primary action | `.accentColor` | `.blue` |
| Sidebar tile fills | system colors: `.blue`, `.green`, `.red`, `.purple`, `.pink`, `.gray`, `Color(.systemGray)` | hardcoded hex |

**Why:** semantic tokens auto-adapt across light/dark mode, increased contrast, custom accent colors. Hardcoded values do not.

### Typography — use named text styles, not point sizes

| Use | SwiftUI | macOS HIG label |
|---|---|---|
| Hero page title (e.g. "General") | `.font(.title)` or `.font(.system(size: 22, weight: .regular))` | Title 1 (22/26) |
| Sub-page title (e.g. "VoiceOver") | `.font(.title2).bold()` | Title 2 (17/22 Bold) |
| Row label, body text | `.font(.body)` | Body (13/16) |
| Section header | `.font(.subheadline)` then `.foregroundStyle(.secondary)` | Subheadline (11/14) |
| Section footer (explanatory) | `.font(.subheadline).foregroundStyle(.secondary)` (or `.tertiary` for lighter) | Subheadline (11/14) |
| Sidebar item label | `.font(.body)` (default in `List`) | Body (13/16) |
| Slider min/max labels under track | `.font(.caption).foregroundStyle(.secondary)` | Caption (11–12) |

**Never** write `.font(.system(size: 13))` for body text. Use `.body`. The system handles dynamic type and accessibility scaling for you.

### Spacing — let `.formStyle(.grouped)` do it

Don't hand-tune padding. `Form { Section { ... } }.formStyle(.grouped)` already produces:

- 20pt gap between section boxes
- 16pt row padding
- Correct section header → box → footer spacing
- Correct divider insets

The few times you do need explicit spacing:

- Hero card vertical padding inside its `Section`: `.padding(.vertical, 6)`
- `SidebarIcon` to label gap: 8pt (handled by `Label`)
- Slider min/max labels gap below track: 4pt

---

## Core components

These are the entire vocabulary of the app. Build them once, use everywhere.

### 1. `GhosttyConfiguratorApp` (the `@main`)

```swift
@main
struct GhosttyConfiguratorApp: App {
    var body: some Scene {
        Window("Ghostty Configurator", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {}
        }
    }
}
```

**Contract:** uses `Window` (not `Settings`, not `WindowGroup`) to get a singleton non-duplicable window. `.contentSize` resizability + content's `.frame` lock the geometry.

### 2. `ContentView` (the root)

```swift
struct ContentView: View {
    @State private var selection: SidebarSection = .appearance
    @StateObject private var store = ConfigStore.shared  // Phase 2+

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Sidebar(selection: $selection)
        } detail: {
            NavigationStack {
                pane(for: selection)
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
        })
    }

    @ViewBuilder private func pane(for section: SidebarSection) -> some View {
        switch section {
        case .appearance:  AppearancePane()
        case .window:      WindowPane()
        case .font:        FontPane()
        // ...
        }
    }
}
```

**Contract:** owns the selection enum; switches over it to render the right pane. Pane structs are stateless; they read from `ConfigStore`.

### 3. `WindowAccessor` (the AppKit bridge)

```swift
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

**Contract:** the ONLY place you reach into AppKit. Used once at root for window chrome lockdown. Never customize per-pane.

### 4. `Sidebar` + `SidebarItem` + `SidebarIcon`

```swift
struct Sidebar: View {
    @Binding var selection: SidebarSection

    var body: some View {
        List(selection: $selection) {
            Section { ForEach(SidebarSection.visualGroup) { row($0) } }
            Section { ForEach(SidebarSection.behaviorGroup) { row($0) } }
            Section { ForEach(SidebarSection.advancedGroup) { row($0) } }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
    }

    private func row(_ section: SidebarSection) -> some View {
        NavigationLink(value: section) {
            Label {
                Text(section.title)
            } icon: {
                SidebarIcon(symbol: section.symbol, tint: section.tint)
            }
        }
    }
}

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
```

**Contract:** flat solid color, white SF Symbol, 20×20pt, 5pt corner radius. No gradients. No shadows. `.listStyle(.sidebar)` auto-applies the sidebar material — do NOT add `.background(.regularMaterial)`.

### 5. `HeroCard`

```swift
struct HeroCard: View {
    let symbol: String
    let title: String
    let description: String
    let iconGradient: [Color]  // e.g. [.purple, .indigo]

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: iconGradient,
                                             startPoint: .top, endPoint: .bottom))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2).bold()
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
```

**Contract:** lives inside its own header-less `Section` at the top of a pane. The Section gives it the rounded background; without it, the card floats nakedly.

Usage:
```swift
Section {
    HeroCard(symbol: "paintpalette.fill",
             title: "Appearance",
             description: "Customize colors, themes, and visual style.",
             iconGradient: [.purple, .pink])
}
```

### 6. `SettingsRow` variants

The atomic building blocks. Always use `LabeledContent` for the "label + trailing control" pattern.

#### 6a. Toggle row

```swift
Toggle("Launch at login", isOn: $store.launchAtLogin)
```

That's it. Don't wrap in `LabeledContent` — `Toggle` already lays out correctly inside a `Form`.

#### 6b. Picker (pop-up menu) row

```swift
LabeledContent("Theme") {
    Picker("", selection: $store.theme) {
        ForEach(themes, id: \.self) { Text($0).tag($0) }
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .fixedSize()
}
```

Don't forget `.labelsHidden()` (avoids duplicate label) and `.fixedSize()` (avoids stretching to fill).

#### 6c. Stepper row

```swift
LabeledContent("Scrollback") {
    Stepper(value: $store.scrollbackMB, in: 1...100, step: 1) {
        Text("\(store.scrollbackMB) MB").monospacedDigit()
    }
}
```

Always `.monospacedDigit()` for numeric values that change.

#### 6d. Slider row (System-Settings style — labels under track)

```swift
LabeledContent("Background opacity") {
    SystemSettingsSlider(
        value: $store.backgroundOpacity,
        in: 0...1,
        leadingLabel: "Transparent",
        trailingLabel: "Opaque"
    )
    .frame(width: 220)
}
```

Where:
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
```

The built-in `Slider(value:in:label:minimumValueLabel:maximumValueLabel:)` puts labels inline with the track. Wrong for System Settings — labels go *under* the track ends.

#### 6e. Disclosure / drill-down row

```swift
NavigationLink(value: AppearanceRoute.fontMetrics) {
    LabeledContent("Font metrics") {
        Text(store.hasCustomFontMetrics ? "Custom" : "Default")
            .foregroundStyle(.secondary)
    }
}
```

`NavigationLink(value:)` (not `destination:`) so it integrates with `NavigationStack` path navigation. The chevron is automatic.

#### 6f. Color picker row

```swift
LabeledContent("Background") {
    ColorPicker("", selection: $store.background)
        .labelsHidden()
}
```

#### 6g. Action button row

```swift
LabeledContent("Custom shaders") {
    Button("Manage…") { showShaderEditor = true }
}
```

### 7. `GroupedSection` (use Form's `Section` directly)

Don't wrap. Use the SwiftUI primitive:

```swift
Section {
    Toggle(...)
    LabeledContent(...) { ... }
} header: {
    Text("Startup")
} footer: {
    Text("Choose how Ghostty behaves at login.")
}
```

For a section without a footer, omit the `footer:` param. For a section that needs explanatory text but no header, omit `header:`.

### 8. `PaneScaffold` (the template each pane follows)

Every pane follows this shape — codify it but don't abstract it too aggressively:

```swift
struct AppearancePane: View {
    @EnvironmentObject var store: ConfigStore
    @State private var route: AppearanceRoute?

    var body: some View {
        Form {
            Section { HeroCard(symbol: "paintpalette.fill", title: "Appearance",
                               description: "...", iconGradient: [.purple, .pink]) }

            Section {
                // ... rows ...
            } header: { Text("Theme") }

            Section {
                // ... rows ...
            } header: { Text("Window") } footer: { Text("...") }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
        .navigationDestination(for: AppearanceRoute.self) { route in
            switch route {
            case .themeBrowser: ThemeBrowserView()
            case .fontMetrics:  FontMetricsView()
            }
        }
    }
}
```

**Contract:** Form > Sections > Rows. Always `.formStyle(.grouped)`. Always set `.navigationTitle`. Use `@EnvironmentObject` to read from `ConfigStore` once injected at root.

---

## Component DON'Ts

A short list of things to never build, because the framework already does them:

| Don't build | Use instead | Why |
|---|---|---|
| Custom toggle switch | `Toggle(...).toggleStyle(.switch)` | You'll never match the spring animation, focus ring, or accent tinting |
| Custom rounded section background | `Form { Section { ... } }.formStyle(.grouped)` | The whole reason `.formStyle(.grouped)` exists |
| Custom sidebar material | `List(...).listStyle(.sidebar)` inside a `NavigationSplitView` sidebar column | AppKit applies it automatically |
| Custom back/forward chevrons in toolbar | `NavigationStack { ... }` in the detail column | Free, animated, history-tracked |
| Custom disclosure chevron on a row | `NavigationLink(value:)` inside a `Section` row | Automatic |
| Custom popup-button double-chevron | `Picker(...).pickerStyle(.menu)` | Renders `chevron.up.chevron.down` automatically |
| Custom focus ring | Native controls have it; never use `.focused()` with custom drawing | Breaks accessibility |
| Custom dark mode color sets | Semantic system colors (`Color.primary`, etc.) | Adapts automatically; respects accessibility settings |
| Custom font sizes | `.font(.body)`, `.font(.title2)`, etc. | Respects Dynamic Type and accessibility text size |

---

## Component DOs that aren't obvious

| Do | Why |
|---|---|
| `.monospacedDigit()` on numeric values that change in steppers/counters | Prevents jitter as digits change width |
| `.fixedSize()` on Pickers inside `LabeledContent` | Prevents the picker stretching to fill |
| `.labelsHidden()` on Pickers inside `LabeledContent` | Avoids duplicate labels |
| `.keyboardShortcut(.defaultAction)` on the primary "Done" button | Free Return-key handling |
| `@SceneStorage("selection")` for sidebar selection | Persists last-viewed pane across app launches (System Settings does this) |
| `NavigationLink(value:)` not `NavigationLink(destination:)` | Required for path-based `NavigationStack` |
| `.windowToolbarStyle(.unified)` on the Scene | Merges toolbar with titlebar — the System Settings look |
| `CommandGroup(replacing: .newItem) {}` | Removes the useless File > New menu item |

---

## When to break these rules

You will, sometimes, need a custom component:

- **Theme tile in the theme browser** — no native primitive for a swatch grid + sample preview. Build a custom `ThemeTile` view.
- **Keybind trigger capture widget** — no native primitive for capturing a key combo and rendering it as shortcut glyphs.
- **Faux-terminal preview pane** — used in theme browser and font preview. Custom `TerminalPreview` view rendering a `Text` with fixed content in the selected font/palette.

That's roughly it. Three custom components for the entire app. Everything else is `Form`, `Section`, `Toggle`, `Picker`, `Slider`, `Stepper`, `LabeledContent`, `NavigationLink`, `Button`.

If you find yourself building a fourth or fifth custom component, stop and ask whether you're fighting the framework.

---

## Verification checklist

Use this before declaring any pane "done":

1. Total window width is exactly 715pt — measure with screenshot.
2. Sidebar selection turns gray (not accent) when window loses focus.
3. Row dividers start at the row label's leading edge (16pt), not at the rounded box's edge.
4. Section header is **Regular 11pt sentence-case**, not iOS-style uppercased semibold.
5. Hero icon corner curvature is continuous squircle (`.continuous`), not simple rounded rect.
6. Footer text uses tertiary label color and wraps inside the content width.
7. Disclosure chevron is `chevron.right` Semibold ~10pt (automatic via `NavigationLink`).
8. Pop-up buttons show `chevron.up.chevron.down` double-chevron (automatic via `pickerStyle(.menu)`).
9. Dark mode: switch system appearance; verify nothing looks wrong.
10. Accent color: change System Settings → Appearance → Accent; verify the configurator adopts it.

If any of these fail, you've hand-customized something you shouldn't have. Find it and delete.

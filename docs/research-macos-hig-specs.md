# Research: macOS System Settings — Design Specification Reference

> Goal: a pixel- and type-level spec sheet to verify a SwiftUI replica of the post-Ventura **System Settings** (macOS 13+) against the originals.

## How to read this document

Every spec is tagged with one of:

- **[HIG]** — explicit value or rule from Apple's Human Interface Guidelines or AppKit docs. Authoritative.
- **[SDK]** — derived from Apple's framework defaults (SwiftUI `Form(.grouped)`, `NSSplitViewController` sidebar style). Authoritative for behavior; numeric values come from the rendered output of those defaults.
- **[OBS]** — observed / measured from the live `System Settings.app` (Ventura → Sequoia → macOS 26). Community-measured, not officially published. Listed with the consensus value and where to confirm.
- **[INF]** — inferred from cross-referencing. Verify against a screenshot before locking in.

References numbered `[n]`; sources at the bottom.

> **Important caveat.** Apple does not publish per-pixel specs for System Settings. HIG's color page warns: *"documented color values are for your reference… actual values may fluctuate from release to release."* [OBS] numbers reflect what shipped builds render and have drifted slightly between Ventura, Sonoma, Sequoia, and macOS 26 (Liquid Glass). Prefer building to AppKit/SwiftUI defaults (`NavigationSplitView` + `.formStyle(.grouped)` + `.sidebar` list style) rather than hard-coding numbers; re-measure for each OS target.

---

## 1. Window dimensions

| Spec | Value | Tag | Notes |
|---|---|---|---|
| Default total width | **~715 pt** | [OBS] | Sidebar ~215 + detail ~500. Fixed default; not horizontally resizable. [9] |
| Sidebar width | **~215 pt** | [OBS] | Apple ships "medium" by default; users can change icon size in General → Appearance, which scales sidebar width up to ~225pt. [HIG: sidebars/macOS] [1] |
| Detail-pane content width | **~500 pt** | [OBS] | Form internal margins eat ~20pt each side → ~460pt usable form width. |
| Minimum height | **~445 pt** | [OBS] | Vertical resize allowed; horizontal disabled (`contentMaxSize` clamps width to default). |
| Default height | **~700 pt** | [OBS] | Enough for ~10 sidebar rows. |
| Maximum height | screen height | [INF] | No explicit cap. |
| Window style | titled + closable + miniaturizable; **not** horizontally resizable | [OBS] | |
| Traffic-light position | inset **(20, 20)** from window's top-left content corner | [INF] | Default for unified-titlebar windows. [HIG: toolbars] [4] |
| Title bar style | unified, transparent; no visible title text in toolbar — pane name is rendered in the content area instead | [OBS] | `titleVisibility = .hidden`, `titlebarAppearsTransparent = true`. |

---

## 2. Sidebar specs

### 2.1 Layout

| Spec | Value | Tag | Notes |
|---|---|---|---|
| Sidebar material | `NSVisualEffectView.material = .sidebar` | **[HIG]** | "The material for the background of window sidebars." [3] In SwiftUI: `NavigationSplitView` applies this automatically. |
| Blending mode | `.behindWindow` | [HIG] | [3] |
| Sidebar top padding (above search field) | **~10 pt** | [OBS] | |
| Search field height | **~22 pt** | [OBS] | Standard `NSSearchField`. |
| Search field horizontal inset | **10 pt** each side | [OBS] | |
| Search field placeholder | "Search" | [OBS] | Tertiary label color. |
| Gap from search field to first row | **~8 pt** | [OBS] | |
| Item row height (Medium) | **~30 pt** | [OBS] | "Sidebar icon size" in General changes this. HIG: row height/text/glyph all scale with sidebar size. [1] |
| Item row height (Small / Large) | **~26 / ~36 pt** | [OBS] | |
| Vertical spacing between rows in same group | **0 pt** (contiguous) | [OBS] | Spacing is internal row padding, not gaps. |
| Section break gap (e.g. Battery → General) | **~18 pt** | [OBS] | Achieved via `Section` in a SwiftUI sidebar List. |
| Row leading padding | **~10 pt** from sidebar edge to tile icon | [OBS] | |
| Gap from tile icon to label | **~8 pt** | [OBS] | |
| Selected-row inset | **5 pt** each side | [OBS] | |
| Selected-row corner radius | **6 pt** | [OBS] | Standard macOS list selection. |
| Selected-row fill | **system accent color** (tracks user accent) | **[HIG]** | "By default, sidebar icons use the current app accent color." [1] Drops to secondary gray when window is unfocused. |
| Selected-row text color | white when focused; primary label when unfocused | [HIG/SDK] | |

### 2.2 Tile icon (the rounded square holding each SF Symbol)

| Spec | Value | Tag |
|---|---|---|
| Tile size | **20 × 20 pt** (Medium) | [OBS] |
| Tile corner radius | **5 pt** | [OBS] |
| SF Symbol inside tile | **~12 pt**, weight `.medium`, scale `.medium`, color white | [OBS] |
| Tile fill | per-category solid color (table below); **flat color, not a gradient** | [OBS] |
| Tile shadow | none | [OBS] |

#### Per-category tile colors

Use the system color name (not raw hex) so values track Apple's drift and dark-mode adapt.

| Category | Color | sRGB hex (light) | Tag |
|---|---|---|---|
| Wi-Fi / Bluetooth / Network / VPN | systemBlue | `#007AFF` | [OBS] |
| Battery | systemGreen | `#34C759` | [OBS] |
| Notifications / Sound | systemRed | `#FF3B30` | [OBS] |
| Focus / Screen Time | systemPurple | `#AF52DE` | [OBS] |
| Appearance | black/graphite | dynamic | [OBS] |
| Accessibility | systemBlue | `#007AFF` | [OBS] |
| Control Center | dark gray | dynamic | [OBS] |
| Siri & Spotlight | multi-color asset (PDF, not tinted symbol) | n/a | [OBS] |
| Apple Intelligence | rainbow gradient (custom asset) | n/a | [OBS] |
| Privacy & Security | systemBlue | `#007AFF` | [OBS] |
| Login Password | gray | dynamic | [OBS] |
| Users & Groups | systemBrown / tan | `#A2845E` | [OBS] |
| Internet Accounts | systemBlue | `#007AFF` | [OBS] |
| Game Center | systemGreen | `#34C759` | [OBS] |
| Wallet & Apple Pay | black | `#000000` | [OBS] |
| Keyboard / Mouse / Trackpad | gray | dynamic | [OBS] |
| Display / Wallpaper | systemBlue | `#007AFF` | [OBS] |
| Desktop & Dock / Screen Saver | gray | dynamic | [OBS] |
| General (incl. About / Software Update / Storage rows) | systemGray | dynamic | [OBS] |

Standard sRGB hex values for system colors are from Apple's published color set [8][10].

### 2.3 Sidebar typography

| Element | Font | Size | Weight | Tag |
|---|---|---|---|---|
| Row label | SF Pro Text | **13 pt** | Regular | [OBS, HIG] — Body (13/16) [2] |
| Section header (rare in System Settings sidebar) | SF Pro Text | 11 pt | Semibold, uppercase | [SDK] |
| Search field text | SF Pro Text | 13 pt | Regular | [SDK] |

---

## 3. Detail pane specs

### 3.1 Layout

| Spec | Value | Tag |
|---|---|---|
| Detail pane background | **window background** (opaque, not vibrancy); light `#ECECEC`–`#EFEFEF`, dark `~#1E1E1E` | [OBS, INF] |
| Top padding (toolbar bottom → first content) | **~20 pt** when hero card present; **~12 pt** when first element is a section header | [OBS] |
| Horizontal content margin | **~20 pt** each side of the form | [OBS] |
| Back / forward chevrons | small buttons in toolbar's leading area | [OBS] |
| Chevron button size | **24 × 24 pt** hit area, **~12 pt** glyph (`chevron.left` / `.right`, regular weight) | [OBS] |
| Chevron enabled state | enabled when navigation history exists; otherwise low-contrast | [OBS] |
| Pane title typography | **Title 1 — 22 pt Regular** for hero pages (Wi-Fi, General); **Title 2 — 17 pt Bold** for sub-pages (Software Update, VoiceOver) | [OBS, HIG] [2] |
| Pane title position | left-aligned in form column on sub-pages; **centered under hero icon** on hero pages | [OBS] |
| Pane title appears | always when navigated into a sub-pane; on top-level panes with a hero card, the hero card replaces a standalone title | [OBS] |

### 3.2 Hero "header card" (e.g. General, Apple ID)

| Spec | Value | Tag |
|---|---|---|
| Container | single grouped-form section, full content width, icon+title+description stacked **centered** | [OBS] |
| Hero icon size | **64 × 64 pt** (76 pt for Apple ID-style avatars) | [OBS] |
| Hero icon corner radius | **14 pt** (concentric with macOS app-icon squircle for that size) | [OBS, HIG] [5] |
| Spacing icon → title | **8 pt** | [OBS] |
| Title typography | Title 1, 22 pt Regular | [OBS, HIG] [2] |
| Description typography | Body, 13 pt Regular, secondary label color | [OBS, HIG] [2] |
| Spacing title → description | **2 pt** | [OBS] |
| Card vertical padding | **20 pt** top and bottom | [OBS] |

### 3.3 Form sections

| Spec | Value | Tag |
|---|---|---|
| Gap between grouped section boxes | **20 pt** | [OBS] — `.formStyle(.grouped)` default. |
| Section header typography | SF Pro Text **11 pt**, **Regular**, **secondary label color**, **not** uppercased | [OBS] — distinct from iOS-style uppercased footnote headers. |
| Section header leading padding | **20 pt** from form column edge (aligns with rounded box's leading edge) | [OBS] |
| Section header → box bottom padding | **6 pt** | [OBS] |
| Section footer (explanatory text) typography | SF Pro Text **11 pt**, Regular, **tertiary label color** | [OBS, HIG] — Subheadline. [2] |
| Section footer top padding | **6 pt** below the rounded box | [OBS] |
| Section footer line wrap | wraps within content width (`section width − 2 × 20`) | [OBS] |

---

## 4. Row specs (inside grouped boxes)

| Spec | Value | Tag |
|---|---|---|
| Group container background | `controlBackgroundColor` — light **`#FFFFFF`**, dark **~`#2A2A2A`** (slightly lighter than window bg) | [OBS, HIG: materials] [3] |
| Group container corner radius | **10 pt** | [OBS] |
| Row height (single line) | **38 pt** | [OBS] |
| Row height (multi-line / subtitle) | **52–60 pt** depending on wrap | [OBS] |
| Row horizontal padding | **16 pt** leading + trailing | [OBS] |
| Divider between rows in same group | **0.5 pt hairline** in `separatorColor` (`#3C3C434A` light / `#54545899` dark) | [OBS, HIG] [3] |
| Divider inset | starts **16 pt** from container's leading edge (aligned to row label, **not** the optional leading icon) | [OBS] |
| Row label typography | SF Pro Text **13 pt Regular**, primary label color | [OBS, HIG] — Body [2] |
| Row sublabel typography | SF Pro Text **11 pt Regular**, secondary label color | [OBS, HIG] — Subheadline [2] |
| Trailing-value typography (e.g. "English (India)", "10") | SF Pro Text **13 pt Regular**, secondary label color | [OBS] |
| Disclosure chevron | `chevron.right`, **10–11 pt**, Semibold, **tertiary label color** | [OBS] |
| Chevron trailing padding | **16 pt** from row edge | [OBS] |
| Gap from trailing value to chevron | **6 pt** | [OBS] |
| Leading row-icon (small rounded tile, e.g. About/Software Update inside General) | **20 × 20 pt**, **5 pt** radius — same shape and size as sidebar tile | [OBS] |
| Leading row-icon → label spacing | **8 pt** | [OBS] |
| Leading row-icon → row leading edge | **16 pt** | [OBS] |

---

## 5. Controls

### 5.1 Toggle (`NSSwitch` / SwiftUI `Toggle`)

| Spec | Value | Tag |
|---|---|---|
| Size (regular) | **38 × 22 pt** track, **18 pt** knob | [OBS] |
| Size (mini, used in dense forms) | **26 × 15 pt** track | [OBS, HIG] — HIG explicitly recommends mini switches for grouped forms. [6] |
| On color | **systemGreen `#34C759`** by default: HIG says *"Default styling uses the system green color, but this can be customized if necessary"* [6]. Some System Settings builds render in **system accent** instead — version-dependent. | [HIG / OBS] |
| Off color | `tertiarySystemFill` — light gray | [OBS] |
| Knob | white in both states, subtle shadow | [OBS] |
| Animation | ~150 ms ease-in-out for knob slide + color cross-fade | [OBS] |

### 5.2 Pop-up button (`NSPopUpButton` / SwiftUI `Picker(.menu)`)

| Spec | Value | Tag |
|---|---|---|
| Height in a form row | **22 pt** (mini, inline); **24 pt** standard | [OBS] |
| Padding | **8 pt** leading, **6 pt** trailing inside button | [OBS] |
| Disclosure indicator | **`chevron.up.chevron.down`** double-chevron, **~9 pt**, secondary color | [OBS] |
| Background | none in form rows; on hover gains a `quaternaryLabel` rounded background — implements the WWDC22 rule "lower visual weight, more prominent control backings on rollover" [7] | [HIG] |
| Font | SF Pro Text 13 pt Regular | [OBS] |

### 5.3 Segmented control

| Spec | Value | Tag |
|---|---|---|
| Height | **24 pt** | [OBS] |
| Padding inside each segment | **12 pt** horizontal | [OBS] |
| Selected pill | inset **2 pt** from segmented control bounds, **6 pt** corner radius, `controlBackgroundColor` fill over `tertiarySystemFill` track | [OBS] |
| Font | SF Pro Text **13 pt**; selected segment becomes **Semibold** | [OBS] |

### 5.4 Slider with min/max labels (e.g. cursor size)

| Spec | Value | Tag |
|---|---|---|
| Track height | **4 pt** | [OBS] |
| Filled portion color | system accent | [OBS, HIG] [1] |
| Unfilled portion color | `tertiarySystemFill` | [OBS] |
| Knob | **18 pt** circle, white, 1pt border + soft shadow | [OBS] |
| Min/max label typography | **11 pt** Regular, secondary label color | [OBS] |
| Label spacing | **8 pt** between label and track end | [OBS] |

### 5.5 Stepper vs. pop-up

| Spec | Value | Tag |
|---|---|---|
| Rule of thumb | Stepper for unbounded / large numeric ranges; pop-up for a small finite enumerated set | [INF] |
| "10" with `↕` for things like "Recent items" | is a **pop-up button** (values 5/10/15/20/None), not a stepper | [OBS] |
| `NSStepper` appearance | two stacked chevrons (`▴ ▾`) inside a 19 × 22 pt control, attached to trailing edge of a text field | [OBS] |

### 5.6 Buttons

| Style | Use | Spec | Tag |
|---|---|---|---|
| Bordered prominent (filled, system accent) | "Done", "Save", "Update Now" | 22 pt mini / 28 pt standard, 5pt corner radius, white **bold** 13pt label | [OBS] |
| Bordered (gray fill) | "Cancel" | Same dimensions, label in primary color | [OBS] |
| Plain (link style) | "Learn More…" | 13pt accent-color text, no background | [OBS] |
| Help button | "?" in a circle | **20 × 20 pt** circle, glyph `questionmark`, positioned at **bottom-right** of pane content with **20 pt** edge margin | [OBS, HIG] [11] |

---

## 6. Materials and color

### 6.1 Materials used

| Surface | Material | Tag |
|---|---|---|
| Sidebar | `NSVisualEffectView.material = .sidebar`, `.behindWindow` blending | **[HIG]** [3] |
| Detail pane background | **`windowBackground`** (opaque, not vibrancy) | [HIG/INF] [3] |
| Grouped section rounded box | solid `controlBackgroundColor` — **flat color, not vibrancy**, so text stays crisp | [OBS, INF] |
| Toolbar | inherits window titlebar (transparent unified) | [OBS] |

### 6.2 Color tokens (semantic, dynamic; resolve in light/dark)

| Token | Light | Dark | Use |
|---|---|---|---|
| `windowBackgroundColor` | `#ECECEC` | `#1E1E1E` | Detail pane base |
| `controlBackgroundColor` | `#FFFFFF` | `#2A2A2A` | Grouped section box |
| `separatorColor` | `rgba(60,60,67,0.29)` | `rgba(84,84,88,0.60)` | Row dividers |
| `labelColor` | `#000000` | `#FFFFFF` | Row labels |
| `secondaryLabelColor` | `rgba(0,0,0,0.5)` | `rgba(255,255,255,0.55)` | Sublabels, trailing values, footer text |
| `tertiaryLabelColor` | `rgba(0,0,0,0.26)` | `rgba(255,255,255,0.25)` | Chevrons, placeholders, disabled |
| `controlAccentColor` | tracks user accent (default `systemBlue #007AFF`) | same | Selection, prominent buttons, filled slider |

Use `NSColor.windowBackgroundColor`, `Color(NSColor.controlBackgroundColor)`, etc. — don't hard-code [8].

### 6.3 Are sidebar tile icons gradients?

**No.** Flat solid system color, white symbol on top. Depth comes from symbol stroke contrast + rounded shape, not a gradient. Exceptions are bespoke assets: **Apple Intelligence** (rainbow gradient), **Siri & Spotlight** (multi-color asset), **Wallet & Apple Pay** (black with accent stripe). [OBS]

---

## 7. Typography hierarchy

Apple's published macOS type scale (HIG Typography) [2]:

| Text style | Weight | Size (pt) | Line height (pt) | Emphasized weight |
|---|---|---|---|---|
| Large Title | Regular | 26 | 32 | Bold |
| Title 1 | Regular | 22 | 26 | Bold |
| Title 2 | Regular | 17 | 22 | Bold |
| Title 3 | Regular | 15 | 20 | Semibold |
| Headline | Bold | 13 | 16 | Heavy |
| Body | Regular | 13 | 16 | Semibold |
| Callout | Regular | 12 | 15 | Semibold |
| Subheadline | Regular | 11 | 14 | Semibold |
| Footnote | Regular | 10 | 13 | Semibold |
| Caption 1 | Regular | 10 | 13 | Medium |
| Caption 2 | Medium | 10 | 13 | Semibold |

### Mapping into System Settings

| UI element | Maps to | Concrete | Tag |
|---|---|---|---|
| Sidebar item label | Body | 13 / Regular | [OBS, HIG] |
| Sidebar section header (rare) | Subheadline | 11 / Semibold | [SDK] |
| Hero page title (General, Wi-Fi) | Title 1 | 22 / Regular | [OBS, HIG] |
| Sub-page title (Software Update) | Title 2 | 17 / Bold | [OBS, HIG] |
| Hero description text | Body | 13 / Regular, secondary | [OBS, HIG] |
| Section header | Subheadline | 11 / **Regular** (macOS uses Regular here, not the table's Semibold "emphasized" variant) | [OBS] |
| Row label | Body | 13 / Regular | [OBS, HIG] |
| Row sublabel | Subheadline | 11 / Regular, secondary | [OBS, HIG] |
| Trailing value | Body | 13 / Regular, secondary | [OBS, HIG] |
| Footer / explanatory text | Subheadline | 11 / Regular, tertiary | [OBS, HIG] |
| Button label | Body | 13 / Regular (Bold for default button) | [OBS, HIG] |

Font face: **SF Pro Text** (resolves via `Font.system(…)` / `NSFont.systemFont(ofSize:)`). For sizes ≥ 20pt, system switches to SF Pro Display automatically.

---

## 8. References

1. **Apple HIG — Sidebars.** `https://developer.apple.com/design/human-interface-guidelines/sidebars` — macOS guidance: row height/text/glyph scale with sidebar size; default icon color is the app accent color; avoid fixed colors. JSON: `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/sidebars.json`
2. **Apple HIG — Typography.** `https://developer.apple.com/design/human-interface-guidelines/typography` — canonical macOS built-in text styles (used in §7). JSON: `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/typography.json`
3. **Apple HIG — Materials** + **`NSVisualEffectView.Material`.** `https://developer.apple.com/design/human-interface-guidelines/materials`, `https://developer.apple.com/documentation/appkit/nsvisualeffectview/material` — 14 active materials including `.sidebar`, `.windowBackground`, `.contentBackground`.
4. **Apple HIG — Toolbars.** `https://developer.apple.com/design/human-interface-guidelines/toolbars` — unified-titlebar pattern, flat items, inline titles.
5. **Apple HIG — App icons.** `https://developer.apple.com/design/human-interface-guidelines/app-icons` — system-masked squircle, corner curvature concentric with device bezel. Same curve System Settings uses for hero icons and sidebar tiles.
6. **Apple HIG — Toggles.** `https://developer.apple.com/design/human-interface-guidelines/toggles` — default on-state is system green; mini switches for grouped forms.
7. **WWDC22 — "What's new in AppKit" (Session 10074).** `https://developer.apple.com/videos/play/wwdc2022/10074/` — single most important Apple-provided source for the System Settings visual language. Confirms the System Preferences → System Settings rename, the new form style ("draws with lower visual weight, reveals more prominent control backings on rollover"), and the recommended SwiftUI implementation `Form { … }.formStyle(.grouped)`.
8. **AppKit `NSColor`.** `https://developer.apple.com/documentation/appkit/nscolor` — system color factories and dynamic semantic colors.
9. **Community measurement / convention.** The ~715pt width and ~215pt sidebar circulate in macOS-developer forums and GitHub replicas. Validate against your own screenshot: ⇧⌘4 + space on System Settings, divide pixel dims by display scale.
10. **SwiftUI `Color`.** `https://developer.apple.com/documentation/swiftui/color`
11. **Apple HIG — Buttons.** `https://developer.apple.com/design/human-interface-guidelines/buttons` — Help button shape, placement (lower-left or lower-right of settings windows/panes).
12. **SwiftUI `Form` + `.grouped`.** `https://developer.apple.com/documentation/swiftui/formstyle/grouped` — implements grouped layout automatically.
13. **SwiftUI `NavigationSplitView`.** `https://developer.apple.com/documentation/swiftui/navigationsplitview` — sidebar+detail with `.sidebar` material.
14. **SwiftUI `defaultSize(width:height:)`.** `https://developer.apple.com/documentation/swiftui/scene/defaultsize(width:height:)` — initial Settings scene size on macOS 13+.
15. **Apple HIG — Search fields.** `https://developer.apple.com/design/human-interface-guidelines/search-fields` — explicitly: *"Apps like Settings take advantage of [search at the top of the sidebar] to quickly filter the sidebar and expose sections that may be multiple levels deep."*

---

## 9. Verification checklist for the SwiftUI replica

1. Total window width within ±2pt of 715.
2. Sidebar uses the system sidebar material — toggle Reduce Transparency; both apps should fall back identically.
3. Toggle color updates when you change System Settings → Appearance → Accent color (or stays green if you're matching the older behavior — pick one).
4. Selected sidebar row turns gray (not accent) when window loses focus.
5. **Row divider inset starts at the row label's leading edge (16pt)**, not at the rounded box's edge — most common detail to miss.
6. Section header is **Regular 11pt sentence-case**, not iOS-style uppercased semibold.
7. Hero icon corner curvature is a continuous squircle (P3-style), not a simple rounded rect — eyedropper the corner.
8. Footer text wraps inside the section's content width and uses tertiary label color.
9. Disclosure chevron is `chevron.right` Semibold ~10pt — not the heavier circled variant.
10. Pop-up button shows `chevron.up.chevron.down` double-chevron — single biggest System Settings tell.

---

**Key tradeoff to keep in mind (PM framing):** Apple deliberately under-documents pixel specs because the system controls *are* the spec. Every spec marked [OBS] above is a place where your replica will diverge if you hard-code numbers and Apple ships a tweak in the next OS. The high-leverage move is to lean on `NavigationSplitView` + `.formStyle(.grouped)` + system colors + system materials, and only fall back to hand-tuned pixels for the bespoke surfaces (hero card composition, sidebar tile color palette, per-category icon assets). That keeps the replica self-updating with the OS — which is how Apple-quality apps stay Apple-quality over years.

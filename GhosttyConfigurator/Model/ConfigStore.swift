import Foundation
import Observation
import os
import SwiftUI

/// Single source of truth for the user-facing config. Backed by a real on-disk
/// Ghostty config file via `ConfigFileIO`.
///
/// Auto-save model (see `docs/03-ux-principles.md` Principle 2): every setter
/// mutates `file`, registers undo, and schedules a 600ms-debounced disk write.
@Observable
@MainActor
final class ConfigStore {
    // MARK: - Public state

    private(set) var file: ConfigFile = .empty
    private(set) var hasLoaded: Bool = false

    let ghosttyInstalled: Bool
    let fileURL: URL
    let defaults = Defaults()

    /// Version string from `ghostty --version`. `nil` until the detection task
    /// finishes (or if Ghostty isn't installed); empty after a successful run
    /// that returned nothing parseable.
    private(set) var ghosttyVersion: String?

    /// Cached `ghostty +list-keybinds --default` output, parsed. `nil` until
    /// the first load attempt completes; empty array on failure (Ghostty
    /// missing, exec failure, or output that failed to parse).
    private(set) var defaultKeybinds: [Keybind]?

    // Validation caches. `knownThemes` is nil until the theme index loads —
    // the validator skips theme checks in that state so it doesn't false-flag.
    private(set) var knownThemes: Set<String>?
    @ObservationIgnored private(set) lazy var knownFontFamilies: Set<String> = Set(NSFontManager.shared
        .availableFontFamilies)

    // MARK: - Defaults

    struct Defaults {
        // Appearance
        let theme: String = "Catppuccin Mocha"
        let backgroundOpacity: Double = 1.0
        let backgroundBlur: BlurLevel = .off

        // Colors (defaults shown in the UI when no value is set yet; the
        // actual Ghostty default comes from the active theme, which we
        // don't resolve here — these only seed the ColorPicker swatch).
        let backgroundColor: Color = .black
        let foregroundColor: Color = .white
        let cursorColorFallback: Color = .white
        let selectionBackgroundFallback: Color = .init(red: 0.20, green: 0.40, blue: 0.85)
        let selectionForegroundFallback: Color = .white
        let boldColorMode: BoldColorMode = .none
        let boldColorCustomFallback: Color = .white
        let minimumContrast: Double = 1.0

        // Window
        let titlebarStyle: TitlebarStyle = .transparent
        let macosWindowButtons: MacosWindowButtons = .visible
        let windowDecoration: WindowDecoration = .auto
        let macosWindowShadow: Bool = true
        let windowPaddingX: Int = 2
        let windowPaddingY: Int = 2
        let windowPaddingBalance: Bool = false
        let macosNonNativeFullscreen: MacosNonNativeFullscreen = .off
        let windowSaveState: WindowSaveState = .default
        let windowTitleFontFamily: String = ""
        let windowWidth: Int = 0
        let windowHeight: Int = 0
        let macosTitlebarProxyIcon: MacosTitlebarProxyIcon = .visible
        let windowPaddingColor: WindowPaddingColor = .background
        let windowNewTabPosition: WindowNewTabPosition = .current
        let resizeOverlay: ResizeOverlay = .afterFirst

        // Cursor
        let cursorStyle: CursorStyle = .block
        let cursorStyleBlink: CursorStyleBlink = .default
        let cursorOpacity: Double = 1.0
        let cursorClickToMove: Bool = false
        let mouseHideWhileTyping: Bool = false
        let cursorTextMode: CursorTextMode = .default
        let cursorTextCustomFallback: Color = .black

        // Font
        let fontFamily: String = "JetBrains Mono"
        let fontFamilyBold: String = ""
        let fontFamilyItalic: String = ""
        let fontFamilyBoldItalic: String = ""
        let fontSize: Double = 13
        let fontThicken: Bool = false
        let fontThickenStrength: Int = 255
        let fontSyntheticStyle: Bool = true
        let fontLigatures: Bool = true
        let fontContextualAlternates: Bool = true
        let fontDiscretionaryLigatures: Bool = false
        let fontHistoricalLigatures: Bool = false
        let fontNumerals: FontNumerals = .default

        // Shell
        let shellIntegration: ShellIntegration = .detect
        let shellFeatureCursor: Bool = true
        let shellFeatureSudo: Bool = false
        let shellFeatureTitle: Bool = true
        let shellFeatureSshEnv: Bool = false
        let shellFeatureSshTerminfo: Bool = false
        let shellCommand: String = ""
        let initialCommand: String = ""
        let workingDirectory: String = ""
        let term: String = "xterm-ghostty"

        // Clipboard & Mouse
        let clipboardRead: ClipboardPermission = .ask
        let clipboardWrite: ClipboardPermission = .allow
        let clipboardPasteProtection: Bool = true
        let clipboardPasteBracketedSafe: Bool = true
        let clipboardTrimTrailingSpaces: Bool = true
        let copyOnSelect: CopyOnSelect = .off
        let selectionClearOnTyping: Bool = true
        let selectionClearOnCopy: Bool = false
        let selectionWordChars: String = "'\"│`|:;,()[]{}<>$"
        let rightClickAction: RightClickAction = .contextMenu
        let mouseShiftCapture: MouseShiftCapture = .falseValue
        // Scrollback
        let scrollbackLimitBytes: Int = 10_000_000
        let scrollToBottomOnKeystroke: Bool = true
        let scrollToBottomOnOutput: Bool = false
        let scrollbar: Scrollbar = .system
        let mouseScrollMultiplier: Double = 1.0
        let mouseReporting: Bool = true
        let focusFollowsMouse: Bool = false

        // Keyboard
        let macosOptionAsAlt: MacosOptionAsAlt = .default
        let macosShortcuts: MacosShortcuts = .ask

        // General
        let autoUpdate: AutoUpdateMode = .check
        let autoUpdateChannel: AutoUpdateChannel = .stable
        let confirmCloseSurface: ConfirmCloseSurface = .whenBusy
        let quitAfterLastWindowClosed: Bool = false
        let desktopNotifications: Bool = true
        let bellAudioVolume: Double = 0.5
        let macosAutoSecureInput: Bool = true
        let macosSecureInputIndication: Bool = true
    }

    // MARK: - IO plumbing

    private let io: ConfigFileIO

    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var watcherTask: Task<Void, Never>?
    @ObservationIgnored private let debounce: Duration = .milliseconds(600)
    @ObservationIgnored weak var undoManager: UndoManager?

    // MARK: - Init

    init(fileURL: URL = ConfigPaths.resolveExistingURL()) {
        self.fileURL = fileURL
        io = ConfigFileIO(fileURL: fileURL)
        ghosttyInstalled = ConfigPaths.ghosttyAppURL() != nil
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            let file = try await io.read()
            self.file = file
            hasLoaded = true
            // swiftformat:disable:next redundantSelf
            Logger.store.info("loaded \(file.parsed.entries.count) entries from \(self.fileURL.path, privacy: .public)")
        } catch {
            Logger.store.error("load failed: \(String(describing: error), privacy: .public)")
            hasLoaded = true
        }
    }

    /// Populate the theme-name set used by the validator. Cheap (just
    /// enumerates filenames in the theme directories — doesn't parse them).
    func loadThemeIndex() async {
        let refs = await ThemeLibrary.shared.index()
        knownThemes = Set(refs.map(\.name))
    }

    /// Shell out to `ghostty --version` once and cache the result for the
    /// About hero. Silent on failure — the About pane just hides the line.
    func loadGhosttyVersion() async {
        ghosttyVersion = await Self.detectGhosttyVersion()
    }

    /// Shell out to `ghostty +list-keybinds --default` once and cache the
    /// parsed list for the Keyboard pane's "Built-in shortcuts" disclosure.
    /// Silent on failure — the section just renders empty.
    func loadDefaultKeybinds() async {
        defaultKeybinds = await Self.fetchDefaultKeybinds()
    }

    private static func fetchDefaultKeybinds() async -> [Keybind] {
        await Task.detached(priority: .utility) { () -> [Keybind] in
            guard let cli = ConfigPaths.ghosttyCLIURL() else { return [] }
            let task = Process()
            task.executableURL = cli
            task.arguments = ["+list-keybinds", "--default"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(bytes: data, encoding: .utf8) ?? ""
                return output.split(separator: "\n").compactMap { rawLine -> Keybind? in
                    var line = rawLine.trimmingCharacters(in: .whitespaces)
                    // Lines look like `keybind = trigger=action`; strip the
                    // `keybind = ` prefix so we feed `KeybindParser` the same
                    // post-`=` payload it sees for user keybinds.
                    if line.lowercased().hasPrefix("keybind"),
                       let eq = line.firstIndex(of: "=")
                    {
                        line = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                    }
                    return KeybindParser.parse(line)
                }
            } catch {
                return []
            }
        }.value
    }

    private static func detectGhosttyVersion() async -> String {
        await Task.detached(priority: .utility) { () -> String in
            guard let cli = ConfigPaths.ghosttyCLIURL() else { return "" }
            let task = Process()
            task.executableURL = cli
            task.arguments = ["--version"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = (String(bytes: data, encoding: .utf8) ?? "")
                guard let first = output.split(separator: "\n").first else { return "" }
                let parts = first.split(separator: " ")
                return parts.count >= 2 ? String(parts[1]) : String(first)
            } catch {
                return ""
            }
        }.value
    }

    /// All current lint findings, keyed by Ghostty docKey. Views look up
    /// their own key via `RowAffix` — no per-pane wiring required.
    var validationIssues: [String: ValidationIssue] {
        Validator.issues(
            for: file,
            knownThemes: knownThemes,
            knownFontFamilies: knownFontFamilies
        )
    }

    func startWatching() {
        watcherTask?.cancel()
        watcherTask = Task { [weak self, fileURL] in
            for await _ in FileWatcher.events(for: fileURL) {
                guard let self else { return }
                await handleExternalEdit()
            }
        }
    }

    func shutdown() async {
        watcherTask?.cancel()
        watcherTask = nil
        if persistTask != nil {
            persistTask?.cancel()
            persistTask = nil
            try? await io.write(file)
        }
    }

    // MARK: - Appearance

    var theme: String {
        get { file.scalarValue(for: "theme") ?? defaults.theme }
        set { setScalar("theme", value: newValue, label: "Change Theme") }
    }

    /// Parses the current `theme = …` value into single vs. light/dark pair.
    /// Reads only — use `setThemeSingle` / `setThemePair` / `clearThemePair`
    /// to mutate, so writes go through the auto-save pipeline.
    var themePair: ThemePair {
        ThemePair(parsing: file.scalarValue(for: "theme"))
    }

    func setThemeSingle(_ name: String) {
        setScalar("theme", value: name, label: "Change Theme")
    }

    func setThemePair(light: String, dark: String) {
        let value = "light:\(quoteIfNeeded(light)),dark:\(quoteIfNeeded(dark))"
        setScalar("theme", value: value, label: "Change Theme Pair")
    }

    private func quoteIfNeeded(_ name: String) -> String {
        if name.contains(" ") || name.contains(",") || name.contains(":") {
            return "\"\(name)\""
        }
        return name
    }

    var backgroundOpacity: Double {
        get { file.double(for: "background-opacity", default: defaults.backgroundOpacity) }
        set { setDouble("background-opacity", newValue, label: "Change Opacity") }
    }

    var backgroundBlur: BlurLevel {
        get {
            guard let raw = file.scalarValue(for: "background-blur") else {
                return defaults.backgroundBlur
            }
            return BlurLevel(rawString: raw) ?? defaults.backgroundBlur
        }
        set { setScalar("background-blur", value: newValue.configValue, label: "Change Background Blur") }
    }

    // MARK: - Colors

    /// `background` — always present semantically (theme provides a default).
    /// When absent or unparseable, the UI falls back to `defaults.backgroundColor`.
    var backgroundColor: Color {
        get { file.color(for: "background") ?? defaults.backgroundColor }
        set { setScalar("background", value: ColorParsing.hexString(from: newValue), label: "Change Background Color") }
    }

    var isBackgroundColorModified: Bool {
        file.scalarValue(for: "background") != nil
    }

    var foregroundColor: Color {
        get { file.color(for: "foreground") ?? defaults.foregroundColor }
        set { setScalar("foreground", value: ColorParsing.hexString(from: newValue), label: "Change Foreground Color") }
    }

    var isForegroundColorModified: Bool {
        file.scalarValue(for: "foreground") != nil
    }

    /// `cursor-color`, `selection-background`, `selection-foreground` —
    /// keys that follow the theme when absent. Use `isAuto*` to drive the
    /// per-row "Auto" toggle in the UI.
    var cursorColor: Color {
        get { file.color(for: "cursor-color") ?? defaults.cursorColorFallback }
        set { setScalar("cursor-color", value: ColorParsing.hexString(from: newValue), label: "Change Cursor Color") }
    }

    var isCursorColorAuto: Bool {
        get { file.scalarValue(for: "cursor-color") == nil }
        set {
            if newValue {
                deleteKey("cursor-color", label: "Reset Cursor Color")
            } else {
                setScalar(
                    "cursor-color",
                    value: ColorParsing.hexString(from: defaults.cursorColorFallback),
                    label: "Set Cursor Color"
                )
            }
        }
    }

    var selectionBackgroundColor: Color {
        get { file.color(for: "selection-background") ?? defaults.selectionBackgroundFallback }
        set { setScalar(
            "selection-background",
            value: ColorParsing.hexString(from: newValue),
            label: "Change Selection Background"
        ) }
    }

    var isSelectionBackgroundAuto: Bool {
        get { file.scalarValue(for: "selection-background") == nil }
        set {
            if newValue {
                deleteKey("selection-background", label: "Reset Selection Background")
            } else {
                setScalar(
                    "selection-background",
                    value: ColorParsing.hexString(from: defaults.selectionBackgroundFallback),
                    label: "Set Selection Background"
                )
            }
        }
    }

    var selectionForegroundColor: Color {
        get { file.color(for: "selection-foreground") ?? defaults.selectionForegroundFallback }
        set { setScalar(
            "selection-foreground",
            value: ColorParsing.hexString(from: newValue),
            label: "Change Selection Foreground"
        ) }
    }

    var isSelectionForegroundAuto: Bool {
        get { file.scalarValue(for: "selection-foreground") == nil }
        set {
            if newValue {
                deleteKey("selection-foreground", label: "Reset Selection Foreground")
            } else {
                setScalar(
                    "selection-foreground",
                    value: ColorParsing.hexString(from: defaults.selectionForegroundFallback),
                    label: "Set Selection Foreground"
                )
            }
        }
    }

    /// `bold-color` — three-mode picker: default (absent), use the bright ANSI
    /// variant, or a literal hex. The custom hex round-trips via `boldColorCustom`.
    var boldColorMode: BoldColorMode {
        get { file.boldColorMode() }
        set {
            switch newValue {
            case .none:
                deleteKey("bold-color", label: "Reset Bold Color")
            case .bright:
                setScalar("bold-color", value: "bright", label: "Use Bright Bold Color")
            case .custom:
                // Only seed a default hex if there isn't already one — preserves
                // the last-chosen custom color when toggling away and back.
                if file.color(for: "bold-color") == nil {
                    setScalar(
                        "bold-color",
                        value: ColorParsing.hexString(from: defaults.boldColorCustomFallback),
                        label: "Use Custom Bold Color"
                    )
                }
            }
        }
    }

    var boldColorCustom: Color {
        get { file.color(for: "bold-color") ?? defaults.boldColorCustomFallback }
        set { setScalar("bold-color", value: ColorParsing.hexString(from: newValue), label: "Change Bold Color") }
    }

    /// `minimum-contrast` — float in [1.0, 21.0]. 1.0 = no enforcement.
    var minimumContrast: Double {
        get { file.double(for: "minimum-contrast", default: defaults.minimumContrast) }
        set { setDouble("minimum-contrast", newValue, label: "Change Minimum Contrast") }
    }

    // MARK: - Window

    var titlebarStyle: TitlebarStyle {
        get { file.enumValue(TitlebarStyle.self, for: "macos-titlebar-style", default: defaults.titlebarStyle) }
        set { setEnum("macos-titlebar-style", newValue, label: "Change Title Bar Style") }
    }

    var macosWindowButtons: MacosWindowButtons {
        get {
            file.enumValue(MacosWindowButtons.self, for: "macos-window-buttons", default: defaults.macosWindowButtons)
        }
        set { setEnum("macos-window-buttons", newValue, label: "Change Window Buttons") }
    }

    var windowDecoration: WindowDecoration {
        get {
            guard let raw = file.scalarValue(for: "window-decoration") else {
                return defaults.windowDecoration
            }
            return WindowDecoration(rawString: raw) ?? defaults.windowDecoration
        }
        set { setEnum("window-decoration", newValue, label: "Change Window Decoration") }
    }

    var macosWindowShadow: Bool {
        get { file.bool(for: "macos-window-shadow", default: defaults.macosWindowShadow) }
        set { setBool("macos-window-shadow", newValue, label: "Toggle Window Shadow") }
    }

    var windowPaddingX: Int {
        get { file.int(for: "window-padding-x", default: defaults.windowPaddingX) }
        set { setInt("window-padding-x", newValue, label: "Change Horizontal Padding") }
    }

    var windowPaddingY: Int {
        get { file.int(for: "window-padding-y", default: defaults.windowPaddingY) }
        set { setInt("window-padding-y", newValue, label: "Change Vertical Padding") }
    }

    var windowPaddingBalance: Bool {
        get { file.bool(for: "window-padding-balance", default: defaults.windowPaddingBalance) }
        set { setBool("window-padding-balance", newValue, label: "Toggle Padding Balance") }
    }

    var macosNonNativeFullscreen: MacosNonNativeFullscreen {
        get {
            file.enumValue(
                MacosNonNativeFullscreen.self,
                for: "macos-non-native-fullscreen",
                default: defaults.macosNonNativeFullscreen
            )
        }
        set { setEnum("macos-non-native-fullscreen", newValue, label: "Change Non-Native Fullscreen") }
    }

    var windowSaveState: WindowSaveState {
        get { file.enumValue(WindowSaveState.self, for: "window-save-state", default: defaults.windowSaveState) }
        set { setEnum("window-save-state", newValue, label: "Change Window Save State") }
    }

    var windowTitleFontFamily: String {
        get { file.scalarValue(for: "window-title-font-family") ?? defaults.windowTitleFontFamily }
        set { setScalar("window-title-font-family", value: newValue, label: "Change Title Font") }
    }

    /// `window-width` / `window-height` — initial cell-grid size. 0 = OS default.
    var windowWidth: Int {
        get { file.int(for: "window-width", default: defaults.windowWidth) }
        set { setInt("window-width", newValue, label: "Change Initial Window Width") }
    }

    var windowHeight: Int {
        get { file.int(for: "window-height", default: defaults.windowHeight) }
        set { setInt("window-height", newValue, label: "Change Initial Window Height") }
    }

    var macosTitlebarProxyIcon: MacosTitlebarProxyIcon {
        get { file.enumValue(
            MacosTitlebarProxyIcon.self,
            for: "macos-titlebar-proxy-icon",
            default: defaults.macosTitlebarProxyIcon
        ) }
        set { setEnum("macos-titlebar-proxy-icon", newValue, label: "Change Titlebar Proxy Icon") }
    }

    var windowPaddingColor: WindowPaddingColor {
        get {
            file.enumValue(WindowPaddingColor.self, for: "window-padding-color", default: defaults.windowPaddingColor)
        }
        set { setEnum("window-padding-color", newValue, label: "Change Padding Color") }
    }

    var windowNewTabPosition: WindowNewTabPosition {
        get { file.enumValue(
            WindowNewTabPosition.self,
            for: "window-new-tab-position",
            default: defaults.windowNewTabPosition
        ) }
        set { setEnum("window-new-tab-position", newValue, label: "Change New Tab Position") }
    }

    var resizeOverlay: ResizeOverlay {
        get { file.enumValue(ResizeOverlay.self, for: "resize-overlay", default: defaults.resizeOverlay) }
        set { setEnum("resize-overlay", newValue, label: "Change Resize Overlay") }
    }

    // MARK: - Cursor

    var cursorStyle: CursorStyle {
        get { file.enumValue(CursorStyle.self, for: "cursor-style", default: defaults.cursorStyle) }
        set { setEnum("cursor-style", newValue, label: "Change Cursor Style") }
    }

    var cursorStyleBlink: CursorStyleBlink {
        get {
            guard let raw = file.scalarValue(for: "cursor-style-blink"), !raw.isEmpty else {
                return .default
            }
            return CursorStyleBlink(rawValue: raw) ?? .default
        }
        set {
            if newValue == .default {
                deleteKey("cursor-style-blink", label: "Reset Cursor Blink")
            } else {
                setScalar("cursor-style-blink", value: newValue.rawValue, label: "Change Cursor Blink")
            }
        }
    }

    /// `cursor-text` — color of text drawn over the cursor. 4-state mode +
    /// custom hex follows the same shape as `bold-color`.
    var cursorTextMode: CursorTextMode {
        get { file.cursorTextMode() }
        set {
            switch newValue {
            case .default:
                deleteKey("cursor-text", label: "Reset Cursor Text Color")
            case .cellBackground:
                setScalar("cursor-text", value: "cell-background", label: "Use Cell Background for Cursor Text")
            case .cellForeground:
                setScalar("cursor-text", value: "cell-foreground", label: "Use Cell Foreground for Cursor Text")
            case .custom:
                if file.color(for: "cursor-text") == nil {
                    setScalar(
                        "cursor-text",
                        value: ColorParsing.hexString(from: defaults.cursorTextCustomFallback),
                        label: "Use Custom Cursor Text Color"
                    )
                }
            }
        }
    }

    var cursorTextCustom: Color {
        get { file.color(for: "cursor-text") ?? defaults.cursorTextCustomFallback }
        set {
            setScalar("cursor-text", value: ColorParsing.hexString(from: newValue), label: "Change Cursor Text Color")
        }
    }

    var cursorOpacity: Double {
        get { file.double(for: "cursor-opacity", default: defaults.cursorOpacity) }
        set { setDouble("cursor-opacity", newValue, label: "Change Cursor Opacity") }
    }

    var cursorClickToMove: Bool {
        get { file.bool(for: "cursor-click-to-move", default: defaults.cursorClickToMove) }
        set { setBool("cursor-click-to-move", newValue, label: "Toggle Click-to-Move Cursor") }
    }

    var mouseHideWhileTyping: Bool {
        get { file.bool(for: "mouse-hide-while-typing", default: defaults.mouseHideWhileTyping) }
        set { setBool("mouse-hide-while-typing", newValue, label: "Toggle Hide Mouse While Typing") }
    }

    // MARK: - Font

    var fontFamily: String {
        get { file.listValues(for: "font-family").first ?? defaults.fontFamily }
        set { setScalar("font-family", value: newValue, label: "Change Font Family") }
    }

    var fontSize: Double {
        get { file.double(for: "font-size", default: defaults.fontSize) }
        set { setDouble("font-size", newValue, label: "Change Font Size") }
    }

    var fontThicken: Bool {
        get { file.bool(for: "font-thicken", default: defaults.fontThicken) }
        set { setBool("font-thicken", newValue, label: "Toggle Font Thicken") }
    }

    /// OpenType `liga` feature toggle. `nil` (no entry) renders as the font's default.
    var fontLigatures: Bool {
        get { file.fontFeatureSign(for: "liga") ?? defaults.fontLigatures }
        set { setFontFeature("liga", sign: newValue, label: "Toggle Standard Ligatures") }
    }

    /// OpenType `calt` (contextual alternates) toggle.
    var fontContextualAlternates: Bool {
        get { file.fontFeatureSign(for: "calt") ?? defaults.fontContextualAlternates }
        set { setFontFeature("calt", sign: newValue, label: "Toggle Contextual Alternates") }
    }

    var fontDiscretionaryLigatures: Bool {
        get { file.fontFeatureSign(for: "dlig") ?? defaults.fontDiscretionaryLigatures }
        set { setFontFeature("dlig", sign: newValue, label: "Toggle Discretionary Ligatures") }
    }

    var fontHistoricalLigatures: Bool {
        get { file.fontFeatureSign(for: "hlig") ?? defaults.fontHistoricalLigatures }
        set { setFontFeature("hlig", sign: newValue, label: "Toggle Historical Ligatures") }
    }

    /// Numerals figure style — exclusive picker mapping to tnum/pnum/onum/lnum.
    var fontNumerals: FontNumerals {
        get { file.fontNumerals() }
        set { setFontNumerals(newValue, label: "Change Numerals Style") }
    }

    /// Bold / italic / bold-italic family overrides. Empty string = "same as
    /// regular" (key absent). Reading collapses any blank/missing value into "".
    var fontFamilyBold: String {
        get { file.scalarValue(for: "font-family-bold") ?? defaults.fontFamilyBold }
        set { setFontFamilyOverride("font-family-bold", value: newValue, label: "Change Bold Font") }
    }

    var fontFamilyItalic: String {
        get { file.scalarValue(for: "font-family-italic") ?? defaults.fontFamilyItalic }
        set { setFontFamilyOverride("font-family-italic", value: newValue, label: "Change Italic Font") }
    }

    var fontFamilyBoldItalic: String {
        get { file.scalarValue(for: "font-family-bold-italic") ?? defaults.fontFamilyBoldItalic }
        set { setFontFamilyOverride("font-family-bold-italic", value: newValue, label: "Change Bold-Italic Font") }
    }

    private func setFontFamilyOverride(_ key: String, value: String, label: String) {
        if value.isEmpty {
            deleteKey(key, label: label)
        } else {
            setScalar(key, value: value, label: label)
        }
    }

    /// `font-thicken-strength` — integer 0–255, only meaningful when
    /// `font-thicken` is on.
    var fontThickenStrength: Int {
        get { file.int(for: "font-thicken-strength", default: defaults.fontThickenStrength) }
        set { setInt("font-thicken-strength", newValue, label: "Change Thicken Strength") }
    }

    /// `font-synthetic-style` — single boolean for "synthesize all missing
    /// styles" (the gap-fix-plan opted for one toggle vs three). True = key
    /// absent (Ghostty default = all three synthesized). False = empty value
    /// (`font-synthetic-style =`), which disables all synthesis.
    var fontSyntheticStyle: Bool {
        get {
            guard let raw = file.scalarValue(for: "font-synthetic-style") else { return true }
            return !raw.isEmpty
        }
        set {
            if newValue {
                deleteKey("font-synthetic-style", label: "Enable Synthetic Styles")
            } else {
                setScalar("font-synthetic-style", value: "", label: "Disable Synthetic Styles")
            }
        }
    }

    // MARK: - Shell

    var shellIntegration: ShellIntegration {
        get {
            guard let raw = file.scalarValue(for: "shell-integration") else {
                return defaults.shellIntegration
            }
            return ShellIntegration(rawString: raw) ?? defaults.shellIntegration
        }
        set { setScalar("shell-integration", value: newValue.configValue, label: "Change Shell Integration") }
    }

    var shellFeatureCursor: Bool {
        get { isShellFeatureEnabled("cursor", default: defaults.shellFeatureCursor) }
        set { setCommaFlag(
            "shell-integration-features",
            flag: "cursor",
            enabled: newValue,
            label: "Toggle Cursor Shape Integration"
        ) }
    }

    var shellFeatureSudo: Bool {
        get { isShellFeatureEnabled("sudo", default: defaults.shellFeatureSudo) }
        set { setCommaFlag("shell-integration-features", flag: "sudo", enabled: newValue, label: "Toggle Sudo Quoting")
        }
    }

    var shellFeatureTitle: Bool {
        get { isShellFeatureEnabled("title", default: defaults.shellFeatureTitle) }
        set { setCommaFlag(
            "shell-integration-features",
            flag: "title",
            enabled: newValue,
            label: "Toggle Title Integration"
        ) }
    }

    var shellFeatureSshEnv: Bool {
        get { isShellFeatureEnabled("ssh-env", default: defaults.shellFeatureSshEnv) }
        set { setCommaFlag(
            "shell-integration-features",
            flag: "ssh-env",
            enabled: newValue,
            label: "Toggle SSH Env Forwarding"
        ) }
    }

    var shellFeatureSshTerminfo: Bool {
        get { isShellFeatureEnabled("ssh-terminfo", default: defaults.shellFeatureSshTerminfo) }
        set { setCommaFlag(
            "shell-integration-features",
            flag: "ssh-terminfo",
            enabled: newValue,
            label: "Toggle SSH Terminfo Forwarding"
        ) }
    }

    var shellCommand: String {
        get { file.scalarValue(for: "command") ?? defaults.shellCommand }
        set { setScalar("command", value: newValue, label: "Change Command") }
    }

    var initialCommand: String {
        get { file.scalarValue(for: "initial-command") ?? defaults.initialCommand }
        set {
            if newValue.isEmpty {
                deleteKey("initial-command", label: "Clear Initial Command")
            } else {
                setScalar("initial-command", value: newValue, label: "Change Initial Command")
            }
        }
    }

    /// Environment variables passed to launched commands. Reads parse the
    /// `env = KEY=VALUE` list; writes rewrite the entire list in one shot,
    /// so the editor can add/remove/reorder rows arbitrarily.
    var envVars: [EnvVar] {
        get { file.envVars() }
        set { setEnvVars(newValue) }
    }

    private func setEnvVars(_ vars: [EnvVar]) {
        let priorValues = file.listValues(for: "env")
        // Drop empty-key rows; trim whitespace from keys to keep the file tidy.
        let serialized = vars
            .map { EnvVar(key: $0.key.trimmingCharacters(in: .whitespaces), value: $0.value) }
            .filter { !$0.key.isEmpty }
            .map(\.serialized)
        guard priorValues != serialized else { return }
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.applyEnvVarsUndo(priorValues, label: "Edit Environment Variables")
            }
        }
        undoManager?.setActionName("Edit Environment Variables")
        file.setList("env", values: serialized)
        schedulePersist()
    }

    private func applyEnvVarsUndo(_ values: [String], label: String) {
        undoManager?.setActionName(label)
        file.setList("env", values: values)
        schedulePersist()
    }

    var workingDirectory: String {
        get { file.scalarValue(for: "working-directory") ?? defaults.workingDirectory }
        set { setScalar("working-directory", value: newValue, label: "Change Working Directory") }
    }

    var term: String {
        get { file.scalarValue(for: "term") ?? defaults.term }
        set { setScalar("term", value: newValue, label: "Change TERM Value") }
    }

    // MARK: - Clipboard & Mouse

    var clipboardRead: ClipboardPermission {
        get { file.enumValue(ClipboardPermission.self, for: "clipboard-read", default: defaults.clipboardRead) }
        set { setEnum("clipboard-read", newValue, label: "Change Clipboard Read Permission") }
    }

    var clipboardWrite: ClipboardPermission {
        get { file.enumValue(ClipboardPermission.self, for: "clipboard-write", default: defaults.clipboardWrite) }
        set { setEnum("clipboard-write", newValue, label: "Change Clipboard Write Permission") }
    }

    var clipboardPasteProtection: Bool {
        get { file.bool(for: "clipboard-paste-protection", default: defaults.clipboardPasteProtection) }
        set { setBool("clipboard-paste-protection", newValue, label: "Toggle Paste Protection") }
    }

    var clipboardTrimTrailingSpaces: Bool {
        get { file.bool(for: "clipboard-trim-trailing-spaces", default: defaults.clipboardTrimTrailingSpaces) }
        set { setBool("clipboard-trim-trailing-spaces", newValue, label: "Toggle Trim Trailing Spaces") }
    }

    var copyOnSelect: CopyOnSelect {
        get {
            guard let raw = file.scalarValue(for: "copy-on-select") else { return defaults.copyOnSelect }
            return CopyOnSelect(rawString: raw) ?? defaults.copyOnSelect
        }
        set { setScalar("copy-on-select", value: newValue.configValue, label: "Change Copy-On-Select") }
    }

    var selectionClearOnTyping: Bool {
        get { file.bool(for: "selection-clear-on-typing", default: defaults.selectionClearOnTyping) }
        set { setBool("selection-clear-on-typing", newValue, label: "Toggle Clear Selection On Typing") }
    }

    var mouseShiftCapture: MouseShiftCapture {
        get { file.enumValue(MouseShiftCapture.self, for: "mouse-shift-capture", default: defaults.mouseShiftCapture) }
        set { setEnum("mouse-shift-capture", newValue, label: "Change Shift Capture") }
    }

    var mouseScrollMultiplier: Double {
        get { file.double(for: "mouse-scroll-multiplier", default: defaults.mouseScrollMultiplier) }
        set { setDouble("mouse-scroll-multiplier", newValue, label: "Change Scroll Multiplier") }
    }

    var mouseReporting: Bool {
        get { file.bool(for: "mouse-reporting", default: defaults.mouseReporting) }
        set { setBool("mouse-reporting", newValue, label: "Toggle Mouse Reporting") }
    }

    var focusFollowsMouse: Bool {
        get { file.bool(for: "focus-follows-mouse", default: defaults.focusFollowsMouse) }
        set { setBool("focus-follows-mouse", newValue, label: "Toggle Focus Follows Mouse") }
    }

    var selectionClearOnCopy: Bool {
        get { file.bool(for: "selection-clear-on-copy", default: defaults.selectionClearOnCopy) }
        set { setBool("selection-clear-on-copy", newValue, label: "Toggle Clear Selection on Copy") }
    }

    var selectionWordChars: String {
        get { file.scalarValue(for: "selection-word-chars") ?? defaults.selectionWordChars }
        set {
            if newValue == defaults.selectionWordChars {
                deleteKey("selection-word-chars", label: "Reset Word Boundaries")
            } else {
                setScalar("selection-word-chars", value: newValue, label: "Change Word Boundaries")
            }
        }
    }

    var clipboardPasteBracketedSafe: Bool {
        get { file.bool(for: "clipboard-paste-bracketed-safe", default: defaults.clipboardPasteBracketedSafe) }
        set { setBool("clipboard-paste-bracketed-safe", newValue, label: "Toggle Bracketed Paste Safety") }
    }

    var rightClickAction: RightClickAction {
        get { file.enumValue(RightClickAction.self, for: "right-click-action", default: defaults.rightClickAction) }
        set { setEnum("right-click-action", newValue, label: "Change Right-Click Action") }
    }

    // MARK: - Scrollback

    /// `scrollback-limit` is stored as bytes on disk. The UI exposes it in
    /// megabytes for legibility; this accessor handles the conversion.
    var scrollbackLimitMB: Double {
        get {
            let bytes = file.int(for: "scrollback-limit", default: defaults.scrollbackLimitBytes)
            return Double(bytes) / 1_000_000.0
        }
        set {
            let bytes = Int(newValue * 1_000_000)
            setInt("scrollback-limit", bytes, label: "Change Scrollback Limit")
        }
    }

    var scrollToBottomOnKeystroke: Bool {
        get { isCommaFlagEnabled("scroll-to-bottom", flag: "keystroke", default: defaults.scrollToBottomOnKeystroke) }
        set { setCommaFlag(
            "scroll-to-bottom",
            flag: "keystroke",
            enabled: newValue,
            label: "Toggle Scroll-To-Bottom on Keystroke"
        ) }
    }

    var scrollToBottomOnOutput: Bool {
        get { isCommaFlagEnabled("scroll-to-bottom", flag: "output", default: defaults.scrollToBottomOnOutput) }
        set { setCommaFlag(
            "scroll-to-bottom",
            flag: "output",
            enabled: newValue,
            label: "Toggle Scroll-To-Bottom on Output"
        ) }
    }

    var scrollbar: Scrollbar {
        get { file.enumValue(Scrollbar.self, for: "scrollbar", default: defaults.scrollbar) }
        set { setEnum("scrollbar", newValue, label: "Change Scrollbar Visibility") }
    }

    // MARK: - General

    var autoUpdate: AutoUpdateMode {
        get { file.enumValue(AutoUpdateMode.self, for: "auto-update", default: defaults.autoUpdate) }
        set { setEnum("auto-update", newValue, label: "Change Auto-Update") }
    }

    var autoUpdateChannel: AutoUpdateChannel {
        get { file.enumValue(AutoUpdateChannel.self, for: "auto-update-channel", default: defaults.autoUpdateChannel) }
        set { setEnum("auto-update-channel", newValue, label: "Change Update Channel") }
    }

    /// `confirm-close-surface` — three states. Default (`true`) is omitted
    /// from disk so the file stays clean; explicit `false` / `always` are
    /// written.
    var confirmCloseSurface: ConfirmCloseSurface {
        get {
            guard let raw = file.scalarValue(for: "confirm-close-surface"), !raw.isEmpty else {
                return .whenBusy
            }
            return ConfirmCloseSurface(rawValue: raw) ?? .whenBusy
        }
        set {
            if newValue == .whenBusy {
                deleteKey("confirm-close-surface", label: "Reset Confirm Close")
            } else {
                setScalar("confirm-close-surface", value: newValue.rawValue, label: "Change Confirm Close")
            }
        }
    }

    var quitAfterLastWindowClosed: Bool {
        get { file.bool(for: "quit-after-last-window-closed", default: defaults.quitAfterLastWindowClosed) }
        set { setBool("quit-after-last-window-closed", newValue, label: "Toggle Quit After Last Window") }
    }

    var desktopNotifications: Bool {
        get { file.bool(for: "desktop-notifications", default: defaults.desktopNotifications) }
        set { setBool("desktop-notifications", newValue, label: "Toggle Desktop Notifications") }
    }

    var bellAudioVolume: Double {
        get { file.double(for: "bell-audio-volume", default: defaults.bellAudioVolume) }
        set { setDouble("bell-audio-volume", newValue, label: "Change Bell Volume") }
    }

    var macosAutoSecureInput: Bool {
        get { file.bool(for: "macos-auto-secure-input", default: defaults.macosAutoSecureInput) }
        set { setBool("macos-auto-secure-input", newValue, label: "Toggle Auto Secure Input") }
    }

    var macosSecureInputIndication: Bool {
        get { file.bool(for: "macos-secure-input-indication", default: defaults.macosSecureInputIndication) }
        set { setBool("macos-secure-input-indication", newValue, label: "Toggle Secure Input Indication") }
    }

    // MARK: - Keyboard

    /// `macos-option-as-alt` — five-state picker. `.default` means the key
    /// is absent; the other four map to documented Ghostty raw values
    /// (`false` / `true` / `left` / `right`).
    var macosOptionAsAlt: MacosOptionAsAlt {
        get {
            guard let raw = file.scalarValue(for: "macos-option-as-alt"), !raw.isEmpty else {
                return .default
            }
            return MacosOptionAsAlt(rawValue: raw) ?? .default
        }
        set {
            if newValue == .default {
                deleteKey("macos-option-as-alt", label: "Reset Option as Alt")
            } else {
                setScalar("macos-option-as-alt", value: newValue.rawValue, label: "Change Option as Alt")
            }
        }
    }

    /// `macos-shortcuts` — Shortcuts.app permission. Picker writes `allow` /
    /// `deny`; selecting the default (`ask`) deletes the key so the file
    /// matches Ghostty's out-of-the-box behaviour.
    var macosShortcuts: MacosShortcuts {
        get {
            guard let raw = file.scalarValue(for: "macos-shortcuts"), !raw.isEmpty else {
                return .ask
            }
            return MacosShortcuts(rawValue: raw) ?? .ask
        }
        set {
            if newValue == .ask {
                deleteKey("macos-shortcuts", label: "Reset macOS Shortcuts")
            } else {
                setScalar("macos-shortcuts", value: newValue.rawValue, label: "Change macOS Shortcuts")
            }
        }
    }

    // MARK: - Keybinds

    /// All user-defined keybinds, parsed from `keybind = …` lines in the config.
    /// Order matches their appearance in the file (later lines win when triggers collide).
    var userKeybinds: [Keybind] {
        file.listValues(for: "keybind").compactMap { KeybindParser.parse($0) }
    }

    func addKeybind(_ keybind: Keybind) {
        let priorValues = file.listValues(for: "keybind")
        var newValues = priorValues
        newValues.append(KeybindParser.serialize(keybind))

        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceKeybindList(priorValues, label: "Add Shortcut")
            }
        }
        undoManager?.setActionName("Add Shortcut")
        file.setList("keybind", values: newValues)
        schedulePersist()
    }

    func removeKeybind(_ keybind: Keybind) {
        let priorValues = file.listValues(for: "keybind")
        let target = KeybindParser.serialize(keybind)
        let newValues = priorValues.filter { $0 != target }
        guard newValues.count != priorValues.count else { return }

        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceKeybindList(priorValues, label: "Delete Shortcut")
            }
        }
        undoManager?.setActionName("Delete Shortcut")
        file.setList("keybind", values: newValues)
        schedulePersist()
    }

    func replaceKeybind(_ old: Keybind, with new: Keybind) {
        let priorValues = file.listValues(for: "keybind")
        let oldSerialized = KeybindParser.serialize(old)
        let newSerialized = KeybindParser.serialize(new)
        var newValues = priorValues
        if let idx = newValues.firstIndex(of: oldSerialized) {
            newValues[idx] = newSerialized
        } else {
            newValues.append(newSerialized)
        }

        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceKeybindList(priorValues, label: "Edit Shortcut")
            }
        }
        undoManager?.setActionName("Edit Shortcut")
        file.setList("keybind", values: newValues)
        schedulePersist()
    }

    private func replaceKeybindList(_ values: [String], label: String) {
        undoManager?.setActionName(label)
        file.setList("keybind", values: values)
        schedulePersist()
    }

    // MARK: - Modification dot

    /// True when the typed value differs from the default. Reads off the
    /// computed accessor so each pane can pass a `\.theme`-style key path.
    func isModified<V: Equatable>(_ keyPath: KeyPath<ConfigStore, V>, default defaultValue: V) -> Bool {
        self[keyPath: keyPath] != defaultValue
    }

    // MARK: - Setter pipeline

    private func setScalar(_ key: String, value: String, label: String) {
        let old = file.scalarValue(for: key)
        let oldDisplay = old ?? ""
        guard oldDisplay != value else { return }

        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                if let old {
                    store.setScalar(key, value: old, label: label)
                } else {
                    store.deleteKey(key, label: label)
                }
            }
        }
        undoManager?.setActionName(label)

        file.setScalar(key, value: value)
        schedulePersist()
    }

    private func setBool(_ key: String, _ value: Bool, label: String) {
        setScalar(key, value: value ? "true" : "false", label: label)
    }

    private func setInt(_ key: String, _ value: Int, label: String) {
        setScalar(key, value: String(value), label: label)
    }

    private func setDouble(_ key: String, _ value: Double, label: String) {
        setScalar(key, value: formatNumber(value), label: label)
    }

    private func setEnum<T: RawRepresentable>(_ key: String, _ value: T, label: String) where T.RawValue == String {
        setScalar(key, value: value.rawValue, label: label)
    }

    private func setFontNumerals(_ mode: FontNumerals, label: String) {
        let priorValues = file.listValues(for: "font-feature")
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceFontFeatureList(priorValues, label: label)
            }
        }
        undoManager?.setActionName(label)
        file.setFontNumerals(mode)
        schedulePersist()
    }

    private func replaceFontFeatureList(_ values: [String], label: String) {
        undoManager?.setActionName(label)
        file.setList("font-feature", values: values)
        schedulePersist()
    }

    private func setFontFeature(_ tag: String, sign: Bool, label: String) {
        // Capture the prior sign so undo can restore (or remove) it.
        let priorSign = file.fontFeatureSign(for: tag)
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.applyFontFeatureUndo(tag, sign: priorSign, label: label)
            }
        }
        undoManager?.setActionName(label)
        file.setFontFeature(tag, sign: sign)
        schedulePersist()
    }

    private func applyFontFeatureUndo(_ tag: String, sign: Bool?, label: String) {
        file.setFontFeature(tag, sign: sign)
        schedulePersist()
    }

    private func setCommaFlag(_ key: String, flag: String, enabled: Bool, label: String) {
        let priorFlags = file.commaFlags(for: key)
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.applyCommaFlagsUndo(key, flags: priorFlags, label: label)
            }
        }
        undoManager?.setActionName(label)
        file.setCommaFlag(key, flag: flag, enabled: enabled)
        schedulePersist()
    }

    private func applyCommaFlagsUndo(_ key: String, flags: Set<String>, label: String) {
        if flags.isEmpty {
            file.delete(key)
        } else {
            file.setScalar(key, value: flags.sorted().joined(separator: ","))
        }
        schedulePersist()
    }

    private func deleteKey(_ key: String, label: String) {
        guard file.contains(key: key) else { return }
        let priorValues = file.listValues(for: key)
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                for value in priorValues {
                    store.file.appendList(key, value: value)
                }
                store.schedulePersist()
            }
        }
        undoManager?.setActionName(label)
        file.delete(key)
        schedulePersist()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        let snapshot = file
        persistTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            do {
                try await io.write(snapshot)
            } catch {
                Logger.store.error("persist failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func handleExternalEdit() async {
        if await io.hasExternalChanges() {
            do {
                let reloaded = try await io.read()
                file = reloaded
                Logger.store.info("reloaded after external edit")
            } catch {
                Logger.store.error("reload failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func isShellFeatureEnabled(_ flag: String, default defaultValue: Bool) -> Bool {
        isCommaFlagEnabled("shell-integration-features", flag: flag, default: defaultValue)
    }

    /// Generic reader for any comma-flag list key (e.g. `scroll-to-bottom`,
    /// `shell-integration-features`). Recognises the `no-` prefix to
    /// explicitly disable, falls back to `defaultValue` when neither form
    /// is present.
    private func isCommaFlagEnabled(_ key: String, flag: String, default defaultValue: Bool) -> Bool {
        let flags = file.commaFlags(for: key)
        if flags.contains(flag) { return true }
        if flags.contains("no-\(flag)") { return false }
        return defaultValue
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}

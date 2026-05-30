import Foundation
import Observation
import SwiftUI
import os

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

    // Validation caches. `knownThemes` is nil until the theme index loads —
    // the validator skips theme checks in that state so it doesn't false-flag.
    private(set) var knownThemes: Set<String>?
    @ObservationIgnored private(set) lazy var knownFontFamilies: Set<String> = {
        Set(NSFontManager.shared.availableFontFamilies)
    }()

    // MARK: - Defaults

    struct Defaults: Sendable {
        // Appearance
        let theme: String = "Catppuccin Mocha"
        let backgroundOpacity: Double = 1.0
        let backgroundBlur: BlurLevel = .off

        // Window
        let titlebarStyle: TitlebarStyle = .transparent
        let macosWindowButtons: MacosWindowButtons = .visible
        let windowDecoration: WindowDecoration = .auto
        let macosWindowShadow: Bool = true
        let windowPaddingX: Int = 2
        let windowPaddingY: Int = 2
        let windowPaddingBalance: Bool = false
        let macosNonNativeFullscreen: Bool = false
        let windowSaveState: WindowSaveState = .default

        // Cursor
        let cursorStyle: CursorStyle = .block
        let cursorStyleBlink: Bool = true
        let cursorOpacity: Double = 1.0
        let cursorClickToMove: Bool = false
        let mouseHideWhileTyping: Bool = false

        // Font
        let fontFamily: String = "JetBrains Mono"
        let fontSize: Double = 13
        let fontThicken: Bool = false
        let fontLigatures: Bool = true
        let fontContextualAlternates: Bool = true

        // Shell
        let shellIntegration: ShellIntegration = .detect
        let shellFeatureCursor: Bool = true
        let shellFeatureSudo: Bool = false
        let shellFeatureTitle: Bool = true
        let shellCommand: String = ""
        let workingDirectory: String = ""
        let term: String = "xterm-ghostty"

        // Clipboard & Mouse
        let clipboardRead: ClipboardPermission = .ask
        let clipboardWrite: ClipboardPermission = .allow
        let clipboardPasteProtection: Bool = true
        let clipboardTrimTrailingSpaces: Bool = true
        let copyOnSelect: CopyOnSelect = .off
        let selectionClearOnTyping: Bool = true
        let mouseShiftCapture: MouseShiftCapture = .falseValue
        let mouseScrollMultiplier: Double = 1.0
        let mouseReporting: Bool = true
        let focusFollowsMouse: Bool = false

        // General
        let autoUpdate: AutoUpdateMode = .check
        let autoUpdateChannel: AutoUpdateChannel = .stable
        let confirmCloseSurface: Bool = true
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
        self.io = ConfigFileIO(fileURL: fileURL)
        self.ghosttyInstalled = ConfigPaths.ghosttyAppURL() != nil
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            let file = try await io.read()
            self.file = file
            self.hasLoaded = true
            Logger.store.info("loaded \(file.parsed.entries.count) entries from \(self.fileURL.path, privacy: .public)")
        } catch {
            Logger.store.error("load failed: \(String(describing: error), privacy: .public)")
            self.hasLoaded = true
        }
    }

    /// Populate the theme-name set used by the validator. Cheap (just
    /// enumerates filenames in the theme directories — doesn't parse them).
    func loadThemeIndex() async {
        let refs = await ThemeLibrary.shared.index()
        self.knownThemes = Set(refs.map(\.name))
    }

    /// Shell out to `ghostty --version` once and cache the result for the
    /// About hero. Silent on failure — the About pane just hides the line.
    func loadGhosttyVersion() async {
        self.ghosttyVersion = await Self.detectGhosttyVersion()
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
                let output = String(decoding: data, as: UTF8.self)
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
                await self.handleExternalEdit()
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

    // MARK: - Window

    var titlebarStyle: TitlebarStyle {
        get { file.enumValue(TitlebarStyle.self, for: "macos-titlebar-style", default: defaults.titlebarStyle) }
        set { setEnum("macos-titlebar-style", newValue, label: "Change Title Bar Style") }
    }

    var macosWindowButtons: MacosWindowButtons {
        get { file.enumValue(MacosWindowButtons.self, for: "macos-window-buttons", default: defaults.macosWindowButtons) }
        set { setEnum("macos-window-buttons", newValue, label: "Change Window Buttons") }
    }

    var windowDecoration: WindowDecoration {
        get { file.enumValue(WindowDecoration.self, for: "window-decoration", default: defaults.windowDecoration) }
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

    var macosNonNativeFullscreen: Bool {
        get { file.bool(for: "macos-non-native-fullscreen", default: defaults.macosNonNativeFullscreen) }
        set { setBool("macos-non-native-fullscreen", newValue, label: "Toggle Non-Native Fullscreen") }
    }

    var windowSaveState: WindowSaveState {
        get { file.enumValue(WindowSaveState.self, for: "window-save-state", default: defaults.windowSaveState) }
        set { setEnum("window-save-state", newValue, label: "Change Window Save State") }
    }

    // MARK: - Cursor

    var cursorStyle: CursorStyle {
        get { file.enumValue(CursorStyle.self, for: "cursor-style", default: defaults.cursorStyle) }
        set { setEnum("cursor-style", newValue, label: "Change Cursor Style") }
    }

    var cursorStyleBlink: Bool {
        get { file.bool(for: "cursor-style-blink", default: defaults.cursorStyleBlink) }
        set { setBool("cursor-style-blink", newValue, label: "Toggle Cursor Blink") }
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
        set { setCommaFlag("shell-integration-features", flag: "cursor", enabled: newValue, label: "Toggle Cursor Shape Integration") }
    }

    var shellFeatureSudo: Bool {
        get { isShellFeatureEnabled("sudo", default: defaults.shellFeatureSudo) }
        set { setCommaFlag("shell-integration-features", flag: "sudo", enabled: newValue, label: "Toggle Sudo Quoting") }
    }

    var shellFeatureTitle: Bool {
        get { isShellFeatureEnabled("title", default: defaults.shellFeatureTitle) }
        set { setCommaFlag("shell-integration-features", flag: "title", enabled: newValue, label: "Toggle Title Integration") }
    }

    var shellCommand: String {
        get { file.scalarValue(for: "command") ?? defaults.shellCommand }
        set { setScalar("command", value: newValue, label: "Change Command") }
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

    // MARK: - General

    var autoUpdate: AutoUpdateMode {
        get { file.enumValue(AutoUpdateMode.self, for: "auto-update", default: defaults.autoUpdate) }
        set { setEnum("auto-update", newValue, label: "Change Auto-Update") }
    }

    var autoUpdateChannel: AutoUpdateChannel {
        get { file.enumValue(AutoUpdateChannel.self, for: "auto-update-channel", default: defaults.autoUpdateChannel) }
        set { setEnum("auto-update-channel", newValue, label: "Change Update Channel") }
    }

    var confirmCloseSurface: Bool {
        get { file.bool(for: "confirm-close-surface", default: defaults.confirmCloseSurface) }
        set { setBool("confirm-close-surface", newValue, label: "Toggle Confirm Close") }
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
            store.replaceKeybindList(priorValues, label: "Add Shortcut")
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
            store.replaceKeybindList(priorValues, label: "Delete Shortcut")
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
            store.replaceKeybindList(priorValues, label: "Edit Shortcut")
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
            if let old {
                store.setScalar(key, value: old, label: label)
            } else {
                store.deleteKey(key, label: label)
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

    private func setFontFeature(_ tag: String, sign: Bool, label: String) {
        // Capture the prior sign so undo can restore (or remove) it.
        let priorSign = file.fontFeatureSign(for: tag)
        undoManager?.registerUndo(withTarget: self) { store in
            store.applyFontFeatureUndo(tag, sign: priorSign, label: label)
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
            store.applyCommaFlagsUndo(key, flags: priorFlags, label: label)
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
            for value in priorValues {
                store.file.appendList(key, value: value)
            }
            store.schedulePersist()
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
            try? await Task.sleep(for: self.debounce)
            guard !Task.isCancelled else { return }
            do {
                try await self.io.write(snapshot)
            } catch {
                Logger.store.error("persist failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func handleExternalEdit() async {
        if await io.hasExternalChanges() {
            do {
                let reloaded = try await io.read()
                self.file = reloaded
                Logger.store.info("reloaded after external edit")
            } catch {
                Logger.store.error("reload failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func isShellFeatureEnabled(_ flag: String, default defaultValue: Bool) -> Bool {
        let flags = file.commaFlags(for: "shell-integration-features")
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

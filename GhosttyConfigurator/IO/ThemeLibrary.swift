import Foundation
import os

/// Theme enumeration + lazy load + cache. Off the main actor — the browser
/// reads via `await`.
///
/// Bundled themes live at `Ghostty.app/Contents/Resources/ghostty/themes/`.
/// User themes live at `~/.config/ghostty/themes/` and
/// `~/Library/Application Support/com.mitchellh.ghostty/themes/`.
actor ThemeLibrary {
    static let shared = ThemeLibrary()

    private var indexCache: [ThemeRef]?
    private var parsed: [String: Theme] = [:]

    // MARK: - Enumeration

    /// All available themes (bundled + user). Cached after first call.
    func index() async -> [ThemeRef] {
        if let cached = indexCache { return cached }

        var refs: [ThemeRef] = []
        for dir in themeDirectories() {
            let isBundled = dir.path.contains("/Applications/Ghostty.app/")
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
                continue
            }
            for filename in names where !filename.hasPrefix(".") {
                let url = dir.appendingPathComponent(filename)
                refs.append(ThemeRef(
                    name: filename,
                    url: url,
                    source: isBundled ? .bundled : .user
                ))
            }
        }
        refs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        indexCache = refs
        Logger.themes.info("indexed \(refs.count) themes")
        return refs
    }

    /// Parse a theme by reference. Cached so repeated loads are free.
    func load(_ ref: ThemeRef) async throws -> Theme {
        if let cached = parsed[ref.name] { return cached }
        let data = try Data(contentsOf: ref.url)
        let source = (String(bytes: data, encoding: .utf8) ?? "")
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let theme = makeTheme(from: file, ref: ref)
        parsed[ref.name] = theme
        return theme
    }

    /// Load every theme. Used by the browser grid once on appear; ~5KB × 463
    /// themes parses in well under a second on Apple Silicon.
    func loadAll() async -> [Theme] {
        let refs = await index()
        var out: [Theme] = []
        out.reserveCapacity(refs.count)
        for ref in refs {
            if let theme = try? await load(ref) {
                out.append(theme)
            }
        }
        return out
    }

    /// Drop both caches so the next `index()` re-walks the filesystem and the
    /// next `load(_:)` re-parses each file. Used by ThemeImport after writing
    /// a new user theme so the browser picks it up immediately.
    func resetCache() {
        indexCache = nil
        parsed.removeAll()
    }

    // MARK: - Helpers

    private func themeDirectories() -> [URL] {
        var dirs: [URL] = []
        if let ghostty = ConfigPaths.ghosttyAppURL() {
            dirs.append(ghostty.appendingPathComponent("Contents/Resources/ghostty/themes"))
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let xdgRoot: URL = {
            if let custom = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !custom.isEmpty {
                return URL(fileURLWithPath: custom)
            }
            return home.appendingPathComponent(".config")
        }()
        dirs.append(xdgRoot.appendingPathComponent("ghostty/themes"))
        dirs.append(home.appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/themes"))
        return dirs
    }

    /// Build a `Theme` from a parsed theme file. Missing palette indices
    /// fall back to a sensible default — same byte every consumer can index
    /// safely on `theme.palette[i]`.
    private nonisolated func makeTheme(from file: ConfigFile, ref: ThemeRef) -> Theme {
        var palette = Array(repeating: "#000000", count: 16)
        for entry in file.parsed.entries {
            guard case let .kv(kv) = entry, kv.key == "palette" else { continue }
            // Value is `INDEX=#HEX` — split once on `=`.
            let parts = kv.value.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, let idx = Int(parts[0]), (0 ..< 16).contains(idx) else { continue }
            palette[idx] = parts[1]
        }

        let bg = file.scalarValue(for: "background") ?? "#000000"
        let fg = file.scalarValue(for: "foreground") ?? "#FFFFFF"

        return Theme(
            name: ref.name,
            sourceURL: ref.url,
            source: ref.source,
            palette: palette,
            background: bg,
            foreground: fg,
            cursorColor: file.scalarValue(for: "cursor-color"),
            cursorText: file.scalarValue(for: "cursor-text"),
            selectionBackground: file.scalarValue(for: "selection-background"),
            selectionForeground: file.scalarValue(for: "selection-foreground")
        )
    }
}

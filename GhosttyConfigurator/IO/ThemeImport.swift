import Foundation
import os

/// Convert third-party terminal color schemes into Ghostty theme format.
/// Supported: ITerm2 `.itermcolors`, Alacritty `.toml`. Windows Terminal
/// JSON is stubbed (format detection picks it up; converter throws).
enum ThemeImport {
    enum Format {
        case iterm2
        case alacritty
        case windowsTerminal
        case unknown

        static func detect(url: URL) -> Format {
            switch url.pathExtension.lowercased() {
            case "itermcolors": .iterm2
            case "toml": .alacritty
            case "json": .windowsTerminal
            default: .unknown
            }
        }
    }

    enum ImportError: Error, CustomStringConvertible {
        case unsupportedFormat
        case parseFailed(String)
        case writeFailed(String)

        var description: String {
            switch self {
            case .unsupportedFormat: "Supported formats: .itermcolors (iTerm2) and .toml (Alacritty)."
            case let .parseFailed(m): "Couldn't parse the theme file: \(m)"
            case let .writeFailed(m): "Couldn't write the theme: \(m)"
            }
        }
    }

    /// Convert one of the supported formats into a Ghostty theme file string
    /// and write it to the user's `themes/` directory. Returns the written URL.
    @discardableResult
    static func importTheme(from url: URL, intoUserThemesDir: URL) throws -> URL {
        let format = Format.detect(url: url)
        let body: String
        let baseName = url.deletingPathExtension().lastPathComponent

        switch format {
        case .iterm2:
            body = try ITerm2.convert(at: url, suggestedName: baseName)
        case .alacritty:
            body = try Alacritty.convert(at: url)
        case .windowsTerminal, .unknown:
            throw ImportError.unsupportedFormat
        }

        try FileManager.default.createDirectory(at: intoUserThemesDir, withIntermediateDirectories: true)
        let dest = intoUserThemesDir.appendingPathComponent(baseName)
        do {
            try body.write(to: dest, atomically: true, encoding: .utf8)
        } catch {
            throw ImportError.writeFailed(error.localizedDescription)
        }
        Logger.themes.info("imported theme to \(dest.path, privacy: .public)")
        return dest
    }
}

// MARK: - ITerm2 importer

private enum ITerm2 {
    /// ITerm2 .itermcolors is an XML plist. Keys are color names ("Ansi 0 Color",
    /// "Background Color", etc.); each is a dict with R/G/B `Red Component`,
    /// `Green Component`, `Blue Component` floats 0.0–1.0.
    static func convert(at url: URL, suggestedName _: String) throws -> String {
        let data = try Data(contentsOf: url)
        let plist: Any
        do {
            plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        } catch {
            throw ThemeImport.ImportError.parseFailed("not a valid plist: \(error.localizedDescription)")
        }
        guard let root = plist as? [String: Any] else {
            throw ThemeImport.ImportError.parseFailed("plist root is not a dictionary")
        }

        var lines: [String] = []

        // ANSI palette 0..15.
        for i in 0 ..< 16 {
            let key = "Ansi \(i) Color"
            if let hex = hexColor(named: key, in: root) {
                lines.append("palette = \(i)=#\(hex)")
            }
        }

        // Standard mappings.
        let mappings: [(itermKey: String, ghosttyKey: String)] = [
            ("Background Color", "background"),
            ("Foreground Color", "foreground"),
            ("Cursor Color", "cursor-color"),
            ("Cursor Text Color", "cursor-text"),
            ("Selection Color", "selection-background"),
            ("Selected Text Color", "selection-foreground")
        ]
        for (itermKey, ghosttyKey) in mappings {
            if let hex = hexColor(named: itermKey, in: root) {
                lines.append("\(ghosttyKey) = #\(hex)")
            }
        }

        if lines.isEmpty {
            throw ThemeImport.ImportError.parseFailed("no recognized color keys found in plist")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Extract a "Red Component" / "Green Component" / "Blue Component" trio
    /// at `dict[name]` and render as a 6-digit hex string.
    private static func hexColor(named name: String, in root: [String: Any]) -> String? {
        guard let entry = root[name] as? [String: Any] else { return nil }
        let r = component(entry["Red Component"])
        let g = component(entry["Green Component"])
        let b = component(entry["Blue Component"])
        guard let r, let g, let b else { return nil }
        return String(format: "%02X%02X%02X", r, g, b)
    }

    private static func component(_ value: Any?) -> Int? {
        if let d = value as? Double {
            return Int((max(0, min(1, d)) * 255).rounded())
        }
        if let n = value as? NSNumber {
            return Int((max(0, min(1, n.doubleValue)) * 255).rounded())
        }
        return nil
    }
}

// MARK: - Alacritty importer

private enum Alacritty {
    /// Alacritty themes are TOML. Colors live under nested tables — primary,
    /// cursor, selection, and the `normal`/`bright` ANSI palettes — with values
    /// as quoted strings in `"#rrggbb"` or `"0xrrggbb"` form. We hand-roll a
    /// minimal reader rather than pull a TOML dependency: the structure is
    /// fixed and flat once flattened to dotted key paths.
    static func convert(at url: URL) throws -> String {
        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ThemeImport.ImportError.parseFailed("couldn't read file: \(error.localizedDescription)")
        }

        let table = parse(source)
        var lines: [String] = []

        // ANSI palette: normal 0..7, bright 8..15.
        let ansiNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
        for (group, base) in [("normal", 0), ("bright", 8)] {
            for (offset, name) in ansiNames.enumerated() {
                if let hex = hex(table["colors.\(group).\(name)"]) {
                    lines.append("palette = \(base + offset)=#\(hex)")
                }
            }
        }

        // Primary / cursor / selection mappings.
        let mappings: [(tomlKey: String, ghosttyKey: String)] = [
            ("colors.primary.background", "background"),
            ("colors.primary.foreground", "foreground"),
            ("colors.cursor.cursor", "cursor-color"),
            ("colors.cursor.text", "cursor-text"),
            ("colors.selection.background", "selection-background"),
            ("colors.selection.text", "selection-foreground")
        ]
        for (tomlKey, ghosttyKey) in mappings {
            if let hex = hex(table[tomlKey]) {
                lines.append("\(ghosttyKey) = #\(hex)")
            }
        }

        if lines.isEmpty {
            throw ThemeImport.ImportError.parseFailed("no recognized color keys found in TOML")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Flatten the TOML into `fullDottedKey -> rawValue`. Tracks the current
    /// `[table.path]` header and prepends it to each `key = value` pair; also
    /// supports dotted keys written inline (`colors.primary.background = ...`).
    private static func parse(_ source: String) -> [String: String] {
        var table: [String: String] = [:]
        var section = ""

        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("["), line.hasSuffix("]") {
                section = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            let fullKey = section.isEmpty ? key : "\(section).\(key)"
            table[fullKey] = value
        }
        return table
    }

    /// Drop a `#` comment that sits outside a quoted string.
    private static func stripComment(_ line: String) -> String {
        var inQuotes = false
        var result = ""
        for char in line {
            if char == "\"" || char == "'" { inQuotes.toggle() }
            if char == "#", !inQuotes { break }
            result.append(char)
        }
        return result
    }

    /// Normalize a quoted Alacritty color (`"#1d1f21"` or `"0x1d1f21"`) to a
    /// bare 6-digit uppercase hex string. Returns nil if it doesn't look like one.
    private static func hex(_ raw: String?) -> String? {
        guard var value = raw else { return nil }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if value.hasPrefix("#") { value.removeFirst() }
        else if value.lowercased().hasPrefix("0x") { value.removeFirst(2) }
        guard value.count == 6, value.allSatisfy(\.isHexDigit) else { return nil }
        return value.uppercased()
    }
}

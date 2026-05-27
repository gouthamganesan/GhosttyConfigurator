import Foundation
import os

/// Convert third-party terminal color schemes into Ghostty theme format.
/// Phase 4.5: iTerm2 `.itermcolors`. Alacritty TOML and Windows Terminal JSON
/// are stubbed for follow-on (the format-detection switch is in place).
enum ThemeImport {
    enum Format {
        case iterm2
        case windowsTerminal
        case unknown

        static func detect(url: URL) -> Format {
            switch url.pathExtension.lowercased() {
            case "itermcolors": return .iterm2
            case "json":        return .windowsTerminal
            default:            return .unknown
            }
        }
    }

    enum ImportError: Error, CustomStringConvertible {
        case unsupportedFormat
        case parseFailed(String)
        case writeFailed(String)

        var description: String {
            switch self {
            case .unsupportedFormat:    "Only .itermcolors files are supported right now."
            case .parseFailed(let m):   "Couldn't parse the theme file: \(m)"
            case .writeFailed(let m):   "Couldn't write the theme: \(m)"
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
            body = try iTerm2.convert(at: url, suggestedName: baseName)
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

// MARK: - iTerm2 importer

private enum iTerm2 {
    /// iTerm2 .itermcolors is an XML plist. Keys are color names ("Ansi 0 Color",
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
        for i in 0..<16 {
            let key = "Ansi \(i) Color"
            if let hex = hexColor(named: key, in: root) {
                lines.append("palette = \(i)=#\(hex)")
            }
        }

        // Standard mappings.
        let mappings: [(itermKey: String, ghosttyKey: String)] = [
            ("Background Color",      "background"),
            ("Foreground Color",      "foreground"),
            ("Cursor Color",          "cursor-color"),
            ("Cursor Text Color",     "cursor-text"),
            ("Selection Color",       "selection-background"),
            ("Selected Text Color",   "selection-foreground")
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

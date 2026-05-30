import Foundation
import AppKit

/// Pure-function lint over the current config file. Returns a dictionary keyed
/// by Ghostty docKey (e.g. "theme", "font-family") so views can pull issues
/// without knowing about the validator at all.
///
/// Designed to be cheap to re-run on every keystroke (handful of dictionary
/// lookups + an NSFontManager call that caches internally).
enum Validator {
    /// `knownThemes` is `nil` when the theme library hasn't finished indexing
    /// — in that state, theme checks are skipped rather than false-flagged.
    static func issues(
        for file: ConfigFile,
        knownThemes: Set<String>?,
        knownFontFamilies: Set<String>
    ) -> [String: ValidationIssue] {
        var issues: [String: ValidationIssue] = [:]

        // MARK: Theme
        if let themeRaw = file.scalarValue(for: "theme"),
           !themeRaw.isEmpty,
           let knownThemes,
           let issue = themeIssue(themeRaw, knownThemes: knownThemes) {
            issues["theme"] = issue
        }

        // MARK: Font family — only check the first entry (the primary).
        // Fallback chain entries are advisory and tolerated by Ghostty.
        if let primary = file.listValues(for: "font-family").first,
           !primary.isEmpty,
           !knownFontFamilies.contains(primary),
           !knownFontFamilies.contains(primary.trimmingCharacters(in: .whitespaces)) {
            issues["font-family"] = .init(
                severity: .warning,
                message: "Font \"\(primary)\" isn't installed on this system. Ghostty will fall back to a built-in monospace face."
            )
        }

        // MARK: font-size — Ghostty rejects ≤ 0 and treats > 96 as a typo.
        if let raw = file.scalarValue(for: "font-size"),
           let value = Double(raw) {
            if value <= 0 {
                issues["font-size"] = .init(
                    severity: .error,
                    message: "Font size must be greater than zero."
                )
            } else if value > 96 {
                issues["font-size"] = .init(
                    severity: .warning,
                    message: "Font size \(formatNumber(value)) is unusually large — likely a typo."
                )
            }
        }

        // MARK: background-opacity — 0 makes the terminal invisible.
        if let raw = file.scalarValue(for: "background-opacity"),
           let value = Double(raw),
           value <= 0 {
            issues["background-opacity"] = .init(
                severity: .warning,
                message: "Background opacity of 0 hides the terminal entirely. Use 0.1 or higher to keep text visible."
            )
        }

        // MARK: command — if the value contains a path, check the file exists.
        if let cmd = file.scalarValue(for: "command"),
           !cmd.isEmpty,
           let issue = commandIssue(cmd) {
            issues["command"] = issue
        }

        // MARK: working-directory — must exist if specified (and not "inherit").
        if let cwd = file.scalarValue(for: "working-directory"),
           !cwd.isEmpty,
           cwd != "inherit",
           let issue = workingDirectoryIssue(cwd) {
            issues["working-directory"] = issue
        }

        return issues
    }

    // MARK: - Per-key helpers

    private static func themeIssue(_ raw: String, knownThemes: Set<String>) -> ValidationIssue? {
        // Pair form: "light:Name1,dark:Name2"
        if raw.contains(":") {
            var missing: [String] = []
            for part in raw.split(separator: ",") {
                let trimmedPart = part.trimmingCharacters(in: .whitespaces)
                guard let colonIdx = trimmedPart.firstIndex(of: ":") else { continue }
                let name = stripQuotes(String(trimmedPart[trimmedPart.index(after: colonIdx)...]))
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && !knownThemes.contains(name) {
                    missing.append(name)
                }
            }
            guard !missing.isEmpty else { return nil }
            let names = missing.map { "\"\($0)\"" }.joined(separator: " and ")
            return .init(
                severity: .warning,
                message: "Theme \(names) isn't in the bundled or user theme library. Drop a file in ~/.config/ghostty/themes/ to add it."
            )
        }

        // Single theme name.
        let name = stripQuotes(raw)
        if !knownThemes.contains(name) {
            return .init(
                severity: .warning,
                message: "Theme \"\(name)\" isn't in the bundled or user theme library."
            )
        }
        return nil
    }

    private static func commandIssue(_ value: String) -> ValidationIssue? {
        // Take the first whitespace-separated token as the executable.
        let executable = value.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? value
        // Bare names (e.g. "fish") are resolved via PATH at runtime — accept.
        guard executable.hasPrefix("/") || executable.hasPrefix("~") else { return nil }
        let expanded = (executable as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), !isDir.boolValue {
            return nil
        }
        return .init(
            severity: .warning,
            message: "No file at \(expanded). Ghostty will fall back to the login shell."
        )
    }

    private static func workingDirectoryIssue(_ value: String) -> ValidationIssue? {
        let expanded = (value as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
            return nil
        }
        return .init(
            severity: .warning,
            message: "Directory \(expanded) doesn't exist. Ghostty will fall back to the launching process's CWD."
        )
    }

    private static func stripQuotes(_ value: String) -> String {
        guard value.count >= 2,
              (value.first == "\"" && value.last == "\"")
                || (value.first == "'" && value.last == "'")
        else { return value }
        return String(value.dropFirst().dropLast())
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}

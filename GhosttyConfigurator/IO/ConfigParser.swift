import Foundation

// MARK: - Entry

/// A single entry in a parsed Ghostty config file. Preserves enough info to
/// serialize byte-for-byte identically — `raw` is the original line minus its
/// terminator. Edits replace `raw` with a freshly generated line.
enum ConfigEntry: Hashable, Sendable {
    case blank
    case comment(raw: String)
    case kv(KV)
    case include(Include)

    struct KV: Hashable, Sendable {
        let key: String                 // canonical: lowercased, trimmed
        let value: String               // unquoted, trimmed
        let raw: String                 // exact original line (terminator stripped)
        let lineNumber: Int             // 1-indexed
    }

    struct Include: Hashable, Sendable {
        let path: String                // unquoted, trimmed (without leading `?`)
        let isOptional: Bool
        let raw: String
        let lineNumber: Int
    }
}

// MARK: - ParsedConfig

/// Result of parsing a config file. Holds enough to round-trip serialize.
struct ParsedConfig: Hashable, Sendable {
    var entries: [ConfigEntry]
    let lineEnding: String              // "\n" or "\r\n"
    let hasTrailingNewline: Bool        // true if the original ended with a terminator

    static let empty = ParsedConfig(entries: [], lineEnding: "\n", hasTrailingNewline: false)
}

// MARK: - Parser

enum ConfigParser {
    /// Parse a Ghostty config source string into entries. Pure function;
    /// totally tolerant of malformed input (preserves unrecognizable lines as
    /// comments so a save never silently drops user content).
    static func parse(_ source: String) -> ParsedConfig {
        let lineEnding: String = source.contains("\r\n") ? "\r\n" : "\n"
        let hasTrailingNewline = source.hasSuffix("\n")

        // Strip the trailing terminator (if any) so split doesn't produce a
        // phantom empty entry. We restore it on serialize.
        var working = source
        if hasTrailingNewline {
            if working.hasSuffix("\r\n") {
                working.removeLast(2)
            } else {
                working.removeLast()
            }
        }

        let rawLines: [String]
        if lineEnding == "\r\n" {
            rawLines = working.components(separatedBy: "\r\n")
        } else {
            rawLines = working.components(separatedBy: "\n")
        }

        var entries: [ConfigEntry] = []
        entries.reserveCapacity(rawLines.count)

        for (idx, raw) in rawLines.enumerated() {
            let lineNumber = idx + 1
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                entries.append(.blank)
                continue
            }

            if trimmed.hasPrefix("#") {
                entries.append(.comment(raw: raw))
                continue
            }

            guard let eqIdx = raw.firstIndex(of: "=") else {
                // Malformed line. Preserve verbatim so a save doesn't drop it.
                entries.append(.comment(raw: raw))
                continue
            }

            let keyPart = String(raw[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let valuePart = String(raw[raw.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            let key = keyPart.lowercased()

            if key == "config-file" {
                let (path, isOptional) = parseIncludePath(valuePart)
                entries.append(.include(.init(
                    path: path,
                    isOptional: isOptional,
                    raw: raw,
                    lineNumber: lineNumber
                )))
            } else {
                let value = unquote(valuePart)
                entries.append(.kv(.init(
                    key: key,
                    value: value,
                    raw: raw,
                    lineNumber: lineNumber
                )))
            }
        }

        return ParsedConfig(
            entries: entries,
            lineEnding: lineEnding,
            hasTrailingNewline: hasTrailingNewline
        )
    }

    // MARK: - Serializer

    /// Serialize a `ParsedConfig` back to a string. Round-trip identity holds
    /// for any input that hasn't been edited (parse → serialize == original).
    static func serialize(_ config: ParsedConfig) -> String {
        let lines: [String] = config.entries.map { entry in
            switch entry {
            case .blank:                     return ""
            case .comment(let raw):          return raw
            case .kv(let kv):                return kv.raw
            case .include(let include):      return include.raw
            }
        }
        var output = lines.joined(separator: config.lineEnding)
        if config.hasTrailingNewline {
            output += config.lineEnding
        }
        return output
    }

    // MARK: - Helpers

    /// Strip surrounding double quotes if present and balanced.
    static func unquote(_ value: String) -> String {
        guard value.count >= 2,
              value.hasPrefix("\""),
              value.hasSuffix("\"")
        else { return value }
        return String(value.dropFirst().dropLast())
    }

    /// Re-emit a value for serialization, quoting only when the parser would
    /// otherwise misread the leading character (`?` triggers optional-include
    /// semantics in `config-file`; `#` would look like a comment).
    static func quoteIfNeeded(_ value: String) -> String {
        guard let first = value.first else { return value }
        if first == "?" || first == "#" {
            return "\"\(value)\""
        }
        return value
    }

    /// Render a key/value pair into a canonical line for new or mutated entries.
    /// Format: `key = value` (single spaces around `=`). For reset semantics
    /// (`value` empty) emits `key =` with no trailing space.
    static func formatKV(key: String, value: String) -> String {
        if value.isEmpty {
            return "\(key) ="
        }
        return "\(key) = \(quoteIfNeeded(value))"
    }

    /// Render a `config-file` directive.
    static func formatInclude(path: String, isOptional: Bool) -> String {
        let prefix = isOptional ? "?" : ""
        return "config-file = \(prefix)\(path)"
    }

    private static func parseIncludePath(_ valuePart: String) -> (String, Bool) {
        // Quoted form first — quoting makes the leading char literal.
        let unquoted = unquote(valuePart)
        if unquoted != valuePart {
            // Was quoted, so the path is literal — no `?` semantics.
            return (unquoted, false)
        }
        if valuePart.hasPrefix("?") {
            return (String(valuePart.dropFirst()), true)
        }
        return (valuePart, false)
    }
}

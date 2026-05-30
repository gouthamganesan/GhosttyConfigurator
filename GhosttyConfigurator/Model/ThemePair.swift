import Foundation

/// Parses and re-serializes Ghostty's `theme = …` value, which can be either:
///   `theme = X`                          (single)
///   `theme = light:X,dark:Y`             (system-appearance pair)
///
/// Values can be quoted (`"Flexoki Light"`) or unquoted. We preserve the
/// pair's exact rendering when round-tripping.
struct ThemePair: Hashable {
    var light: String?
    var dark: String?
    var single: String?

    /// True when the value is a `light:…,dark:…` pair.
    var isPair: Bool {
        light != nil && dark != nil
    }

    init() {}

    static let empty = ThemePair()

    // MARK: - Parse

    init(parsing raw: String?) {
        guard let raw, !raw.isEmpty else { return }

        // Heuristic: if both "light:" and "dark:" markers exist near the
        // start of clauses, parse as a pair. Otherwise treat as single.
        if let pair = Self.parseAsPair(raw) {
            light = pair.light
            dark = pair.dark
        } else {
            single = raw
        }
    }

    // MARK: - Serialize

    /// Build the config-line value for the current state. Returns nil when
    /// the pair is empty.
    func serialized() -> String? {
        if let single { return single }
        if let light, let dark {
            return "light:\(quoteIfNeeded(light)),dark:\(quoteIfNeeded(dark))"
        }
        return nil
    }

    // MARK: - Helpers

    private static func parseAsPair(_ raw: String) -> (light: String, dark: String)? {
        let parts = splitTopLevelCommas(raw)
        var light: String?
        var dark: String?
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = trimmed[..<colon].lowercased()
            let valueRaw = String(trimmed[trimmed.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            let value = unquote(valueRaw)
            switch key {
            case "light": light = value
            case "dark": dark = value
            default: continue
            }
        }
        if let light, let dark { return (light, dark) }
        return nil
    }

    /// Split on top-level commas (outside quotes).
    private static func splitTopLevelCommas(_ raw: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inQuotes = false
        for ch in raw {
            if ch == "\"" { inQuotes.toggle() }
            if ch == ",", !inQuotes {
                out.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private static func unquote(_ s: String) -> String {
        if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
            return String(s.dropFirst().dropLast())
        }
        return s
    }

    private func quoteIfNeeded(_ name: String) -> String {
        // Names with commas or colons MUST be quoted to round-trip; names with
        // spaces don't need quoting but Ghostty's own theme list uses quotes
        // for any multi-word theme, so match that convention.
        if name.contains(" ") || name.contains(",") || name.contains(":") {
            return "\"\(name)\""
        }
        return name
    }
}

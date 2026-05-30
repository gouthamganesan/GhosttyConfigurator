import Foundation
import SwiftUI

/// Value type wrapping a parsed config file with editing operations that
/// preserve comments, blank lines, and ordering of unrelated entries.
///
/// Edit semantics follow `docs/research-ghostty-config.md` §7.3:
/// - **Scalar set** — replace the last matching `kv`, or append if none.
/// - **List set** — replace all matching `kv` entries with the new list.
/// - **List append** — add a `kv` after the last matching one, or at end.
/// - **Reset** — emit `key =` (empty value), the documented "use default" form.
/// - **Delete** — drop the matching `kv` lines entirely (different from reset).
struct ConfigFile: Hashable {
    var parsed: ParsedConfig

    init(parsed: ParsedConfig = .empty) {
        self.parsed = parsed
    }

    static let empty = ConfigFile()

    // MARK: - Reading

    /// Last set value for `key` (or nil if absent). Mirrors Ghostty's
    /// "later overrides earlier" semantics for scalar keys.
    func scalarValue(for key: String) -> String? {
        let canonical = key.lowercased()
        var last: String?
        for entry in parsed.entries {
            if case let .kv(kv) = entry, kv.key == canonical {
                last = kv.value
            }
        }
        return last
    }

    /// All values for a list-typed key, in source order.
    func listValues(for key: String) -> [String] {
        let canonical = key.lowercased()
        return parsed.entries.compactMap {
            if case let .kv(kv) = $0, kv.key == canonical { return kv.value }
            return nil
        }
    }

    /// True if any `kv` entry exists for `key`.
    func contains(key: String) -> Bool {
        let canonical = key.lowercased()
        return parsed.entries.contains { entry in
            if case let .kv(kv) = entry { return kv.key == canonical }
            return false
        }
    }

    /// All include directives, in source order.
    func includes() -> [ConfigEntry.Include] {
        parsed.entries.compactMap {
            if case let .include(inc) = $0 { return inc }
            return nil
        }
    }

    // MARK: - Mutation (scalar)

    /// Set a scalar key. Mutates the last existing `kv` for `key`; appends if
    /// none. Returns whether the file actually changed.
    @discardableResult
    mutating func setScalar(_ key: String, value: String) -> Bool {
        let canonical = key.lowercased()
        var lastIndex: Int?
        for (i, entry) in parsed.entries.enumerated() {
            if case let .kv(kv) = entry, kv.key == canonical {
                lastIndex = i
            }
        }
        let newRaw = ConfigParser.formatKV(key: canonical, value: value)

        if let i = lastIndex {
            if case let .kv(kv) = parsed.entries[i], kv.value == value, kv.raw == newRaw {
                return false
            }
            parsed.entries[i] = .kv(.init(
                key: canonical,
                value: value,
                raw: newRaw,
                lineNumber: lineNumber(for: i)
            ))
        } else {
            parsed.entries.append(.kv(.init(
                key: canonical,
                value: value,
                raw: newRaw,
                lineNumber: parsed.entries.count + 1
            )))
        }
        return true
    }

    // MARK: - Mutation (list)

    /// Replace all existing entries for `key` with `values`, in order.
    /// Empty `values` deletes the key entirely (use `reset(key:)` for the
    /// `key =` semantics).
    @discardableResult
    mutating func setList(_ key: String, values: [String]) -> Bool {
        let canonical = key.lowercased()
        let current = listValues(for: canonical)
        guard current != values else { return false }

        // Find first matching index (anchor) and remove all matching entries.
        var firstMatch: Int?
        var newEntries: [ConfigEntry] = []
        newEntries.reserveCapacity(parsed.entries.count)
        for entry in parsed.entries {
            if case let .kv(kv) = entry, kv.key == canonical {
                if firstMatch == nil { firstMatch = newEntries.count }
                continue
            }
            newEntries.append(entry)
        }

        // Insert the new entries at the anchor (or append if none existed).
        let inserts: [ConfigEntry] = values.map { value in
            .kv(.init(
                key: canonical,
                value: value,
                raw: ConfigParser.formatKV(key: canonical, value: value),
                lineNumber: 0
            ))
        }

        if let anchor = firstMatch {
            newEntries.insert(contentsOf: inserts, at: anchor)
        } else {
            newEntries.append(contentsOf: inserts)
        }
        parsed.entries = newEntries
        return true
    }

    /// Append a single value to a list-typed key. If no existing entries,
    /// the value is appended at the end of the file.
    @discardableResult
    mutating func appendList(_ key: String, value: String) -> Bool {
        let canonical = key.lowercased()
        let entry: ConfigEntry = .kv(.init(
            key: canonical,
            value: value,
            raw: ConfigParser.formatKV(key: canonical, value: value),
            lineNumber: 0
        ))

        var lastMatch: Int?
        for (i, e) in parsed.entries.enumerated() {
            if case let .kv(kv) = e, kv.key == canonical { lastMatch = i }
        }
        if let i = lastMatch {
            parsed.entries.insert(entry, at: i + 1)
        } else {
            parsed.entries.append(entry)
        }
        return true
    }

    // MARK: - Reset / delete

    /// Emit `key =` (empty value). Documented "reset to default" form.
    @discardableResult
    mutating func reset(_ key: String) -> Bool {
        setScalar(key, value: "")
    }

    /// Drop every `kv` entry for `key`. Different from `reset` — `reset`
    /// writes an explicit "use default" marker; `delete` removes the lines.
    @discardableResult
    mutating func delete(_ key: String) -> Bool {
        let canonical = key.lowercased()
        let before = parsed.entries.count
        parsed.entries.removeAll {
            if case let .kv(kv) = $0 { return kv.key == canonical }
            return false
        }
        return parsed.entries.count != before
    }

    // MARK: - Typed reads

    /// Parse the last value for `key` as a Bool. Recognizes `"true"`/`"false"`
    /// (Ghostty's canonical encoding). Falls back to `default` for missing or
    /// unparseable values.
    func bool(for key: String, default defaultValue: Bool) -> Bool {
        guard let raw = scalarValue(for: key) else { return defaultValue }
        switch raw.lowercased() {
        case "true": return true
        case "false": return false
        default: return defaultValue
        }
    }

    func int(for key: String, default defaultValue: Int) -> Int {
        guard let raw = scalarValue(for: key), let n = Int(raw) else { return defaultValue }
        return n
    }

    func double(for key: String, default defaultValue: Double) -> Double {
        guard let raw = scalarValue(for: key), let d = Double(raw) else { return defaultValue }
        return d
    }

    func enumValue<T: RawRepresentable>(_ type: T.Type, for key: String, default defaultValue: T) -> T
        where T.RawValue == String
    {
        guard let raw = scalarValue(for: key), let value = T(rawValue: raw) else {
            return defaultValue
        }
        return value
    }

    /// Parse the last value for `key` as a SwiftUI `Color`. Returns `nil` if
    /// the key is absent or the value doesn't parse as `#RRGGBB`/`#RGB`.
    func color(for key: String) -> Color? {
        guard let raw = scalarValue(for: key) else { return nil }
        return ColorParsing.color(from: raw)
    }

    /// Derive the `bold-color` tri-state from the raw config value. Pure —
    /// no I/O, so tests can exercise it directly without a `ConfigStore`.
    func boldColorMode() -> BoldColorMode {
        guard let raw = scalarValue(for: "bold-color"), !raw.isEmpty else {
            return .none
        }
        if raw.lowercased() == "bright" { return .bright }
        if ColorParsing.color(from: raw) != nil { return .custom }
        return .none
    }

    /// All `env = KEY=VALUE` entries, parsed in source order. Malformed
    /// rows (missing `=` or empty key) are dropped — they wouldn't round-trip
    /// safely through the editor anyway.
    func envVars() -> [EnvVar] {
        listValues(for: "env").compactMap { EnvVar.parse($0) }
    }

    /// Derive the `cursor-text` 4-state from the raw config value.
    func cursorTextMode() -> CursorTextMode {
        guard let raw = scalarValue(for: "cursor-text"), !raw.isEmpty else {
            return .default
        }
        switch raw.lowercased() {
        case "cell-background": return .cellBackground
        case "cell-foreground": return .cellForeground
        default:
            return ColorParsing.color(from: raw) != nil ? .custom : .default
        }
    }

    // MARK: - Font-feature flag list

    /// `font-feature` is a list of `+tag` / `-tag` entries (e.g. `+liga`, `-calt`).
    /// Returns the current sign for a tag, or `nil` if no entry exists.
    /// Sign `true` = enabled (`+`), `false` = disabled (`-`).
    func fontFeatureSign(for tag: String) -> Bool? {
        for value in listValues(for: "font-feature") {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { continue }
            let prefix = trimmed.first
            let body = String(trimmed.dropFirst())
            if body.caseInsensitiveCompare(tag) == .orderedSame {
                if prefix == "+" { return true }
                if prefix == "-" { return false }
            }
        }
        return nil
    }

    /// Derive the active numerals mode by inspecting tnum/pnum/onum/lnum.
    /// If multiple are set (which would be unusual), the *last-write-wins*
    /// scan picks the one nearest the end of the file.
    func fontNumerals() -> FontNumerals {
        var winner: FontNumerals = .default
        for value in listValues(for: "font-feature") {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard trimmed.first == "+", trimmed.count >= 2 else { continue }
            let tag = String(trimmed.dropFirst()).lowercased()
            if let mode = FontNumerals(rawValue: tag), mode != .default {
                winner = mode
            }
        }
        return winner
    }

    /// Switch to a numerals mode. Removes the other three tnum/pnum/onum/lnum
    /// `+tag` entries first to keep them mutually exclusive.
    @discardableResult
    mutating func setFontNumerals(_ mode: FontNumerals) -> Bool {
        let tags: Set = ["tnum", "pnum", "onum", "lnum"]
        var values = listValues(for: "font-feature").filter { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return true }
            let prefix = trimmed.first
            let tag = String(trimmed.dropFirst()).lowercased()
            // Drop any +tag / -tag matching the numerals set.
            if prefix == "+" || prefix == "-", tags.contains(tag) {
                return false
            }
            return true
        }
        if mode != .default {
            values.append("+\(mode.rawValue)")
        }
        return setList("font-feature", values: values)
    }

    /// Set a single font feature to `+tag` or `-tag`. Preserves other features.
    /// Pass `nil` to remove the tag entirely (Ghostty falls back to font default).
    @discardableResult
    mutating func setFontFeature(_ tag: String, sign: Bool?) -> Bool {
        var values = listValues(for: "font-feature")
        // Drop any existing entry for this tag.
        values.removeAll { value in
            let body = value.trimmingCharacters(in: .whitespaces)
            guard body.count >= 2 else { return false }
            return body.dropFirst().caseInsensitiveCompare(tag) == .orderedSame
        }
        if let sign {
            let prefix = sign ? "+" : "-"
            values.append("\(prefix)\(tag)")
        }
        return setList("font-feature", values: values)
    }

    // MARK: - Comma-separated flag list (e.g. shell-integration-features)

    /// Ghostty encodes some "list of flags" keys as a single comma-separated
    /// value: `shell-integration-features = cursor,sudo,no-title`. Returns the
    /// set of enabled flags. Flags prefixed with `no-` are explicitly disabled
    /// — the caller decides how to handle that.
    func commaFlags(for key: String) -> Set<String> {
        guard let raw = scalarValue(for: key) else { return [] }
        return Set(raw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        })
    }

    /// Toggle a single flag in a comma-separated list. Setting `enabled = false`
    /// for a feature like `cursor` writes the explicit disable form `no-cursor`,
    /// per Ghostty's `shell-integration-features` semantics.
    @discardableResult
    mutating func setCommaFlag(_ key: String, flag: String, enabled: Bool) -> Bool {
        var flags = commaFlags(for: key)
        let positive = flag
        let negative = "no-\(flag)"
        flags.remove(positive)
        flags.remove(negative)
        flags.insert(enabled ? positive : negative)

        let joined = flags.sorted().joined(separator: ",")
        return setScalar(key, value: joined)
    }

    // MARK: - Serialization

    func serialized() -> String {
        ConfigParser.serialize(parsed)
    }

    // MARK: - Helpers

    private func lineNumber(for index: Int) -> Int {
        if case let .kv(kv) = parsed.entries[index] { return kv.lineNumber }
        return index + 1
    }
}

import Foundation

/// A single `env = KEY=VALUE` entry. The list editor in ShellPane keeps an
/// array of these as its local edit state, then writes the whole list back
/// to `ConfigFile` via `ConfigStore.envVars`.
///
/// `id` is a fresh UUID so SwiftUI ForEach can track rows through edits;
/// equality intentionally ignores it (two rows with the same KEY/VALUE are
/// considered equal for diffing purposes).
struct EnvVar: Identifiable, Hashable, Sendable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }

    static func == (lhs: EnvVar, rhs: EnvVar) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }

    /// Parse `KEY=VALUE` form. Returns nil for malformed entries (missing `=`
    /// or empty key) so the caller can drop them silently.
    static func parse(_ raw: String) -> EnvVar? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let eq = trimmed.firstIndex(of: "=") else { return nil }
        let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[trimmed.index(after: eq)...])
        guard !key.isEmpty else { return nil }
        return EnvVar(key: key, value: value)
    }

    /// Serialize as the raw string Ghostty expects after `env = `.
    var serialized: String { "\(key)=\(value)" }
}

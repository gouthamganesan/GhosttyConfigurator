import Foundation

/// Schema entry for a single Ghostty config key. Sourced from
/// `ghostty +show-config --default --docs` at first launch and cached on disk.
struct SchemaEntry: Codable, Hashable, Sendable {
    let key: String
    let defaultValue: String           // raw value as Ghostty prints it (often empty for unset defaults)
    let docs: String                   // doc paragraph(s), `#` prefixes stripped, paragraphs joined with \n\n
}

/// Snapshot of the Ghostty schema cached to disk.
struct Schema: Codable, Hashable, Sendable {
    let ghosttyVersion: String
    let entries: [String: SchemaEntry]

    static let empty = Schema(ghosttyVersion: "", entries: [:])

    func entry(for key: String) -> SchemaEntry? {
        entries[key]
    }
}

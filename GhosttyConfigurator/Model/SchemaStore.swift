import Foundation
import Observation
import os

/// Globally observable schema store. ConfigStore reads from this for defaults
/// and DocTooltip pulls doc text from here.
@Observable
@MainActor
final class SchemaStore {
    static let shared = SchemaStore()

    private(set) var schema: Schema = .empty
    private(set) var isLoaded: Bool = false

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        let result = await SchemaIntrospector.shared.schema()
        self.schema = result
        self.isLoaded = true
        Logger.parser.info("SchemaStore loaded \(result.entries.count) entries")
    }

    func entry(for key: String) -> SchemaEntry? {
        schema.entry(for: key)
    }

    /// Default value from the schema, falling back to the caller's value.
    func defaultValue(for key: String, fallback: String) -> String {
        schema.entry(for: key)?.defaultValue ?? fallback
    }
}

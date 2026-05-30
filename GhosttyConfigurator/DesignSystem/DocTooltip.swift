import SwiftUI

/// Info-circle that surfaces documentation for a config row. Curated entries
/// from `DocOverrides` take precedence — for rows where the upstream Ghostty
/// docs are too generic (e.g. each OpenType feature toggle mapping to the
/// catch-all `font-feature` entry), we hand-write educational copy.
/// Otherwise falls back to `SchemaStore.shared`, which reads
/// `ghostty +show-config --default --docs` at first launch and caches per
/// Ghostty version.
struct DocTooltip: View {
    let key: String
    @State private var isShown = false
    @Environment(SchemaStore.self) private var schemaStore

    /// Most keys map 1:1 to a schema entry, but a few `docKey:` strings the
    /// panes pass aren't real Ghostty keys (e.g. "shell-integration-features
    /// (cursor)"). Strip parenthetical context to find the underlying key
    /// when we need to fall back to the schema.
    private var lookupKey: String {
        if let paren = key.firstIndex(of: "(") {
            return String(key[..<paren]).trimmingCharacters(in: .whitespaces)
        }
        return key
    }

    private var override: DocOverrides.Entry? {
        DocOverrides.lookup(key)
    }

    var body: some View {
        Button {
            isShown.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .help("View documentation for \(key)")
        .popover(isPresented: $isShown, arrowEdge: .leading) {
            popoverContent
                .padding(14)
                .frame(width: 360)
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let override {
            overrideContent(override)
        } else {
            schemaContent
        }
    }

    private func overrideContent(_ entry: DocOverrides.Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.title)
                .font(.headline)

            Text(.init(entry.body)) // markdown-style **bold** + bullets
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let link = entry.link {
                Link("Learn more ↗", destination: link)
                    .font(.callout)
            }
        }
    }

    private var schemaContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lookupKey)
                .font(.system(.body, design: .monospaced))
                .bold()

            if let entry = schemaStore.entry(for: lookupKey) {
                if !entry.docs.isEmpty {
                    Text(entry.docs)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                if !entry.defaultValue.isEmpty {
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Text("Default:")
                            .foregroundStyle(.secondary)
                        Text(entry.defaultValue)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .font(.callout)
                }
            } else if !schemaStore.isLoaded {
                Text("Loading schema…")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                Text(
                    "No schema entry found for this key. It may have been removed in your Ghostty version, or this row maps to a friendly toggle that doesn't have a 1:1 key."
                )
                .foregroundStyle(.secondary)
                .font(.callout)
            }

            Link(
                "View in Ghostty docs ↗",
                destination: URL(string: "https://ghostty.org/docs/config/reference")!
            )
            .font(.callout)
        }
    }
}

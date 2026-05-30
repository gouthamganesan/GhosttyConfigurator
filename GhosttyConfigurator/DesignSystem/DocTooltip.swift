import AppKit
import SwiftUI

/// Info-circle that surfaces documentation for a config row. Curated entries
/// from `DocOverrides` take precedence — for rows where the upstream Ghostty
/// docs are too generic (e.g. each OpenType feature toggle mapping to the
/// catch-all `font-feature` entry), we hand-write educational copy.
/// Otherwise falls back to `SchemaStore.shared`, which reads
/// `ghostty +show-config --default --docs` at first launch and caches per
/// Ghostty version.
///
/// Always includes a Provenance section (A4): "Set in: `<file>:<line>`" if
/// the user has written the key, plus the bundled default from the schema.
/// Reveals the merge order in the way `docs/00-PLAN.md` §6.4 calls out —
/// "default to revealing what Ghostty does".
struct DocTooltip: View {
    let key: String
    @State private var isShown = false
    @Environment(SchemaStore.self) private var schemaStore
    @Environment(ConfigStore.self) private var configStore

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

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let override {
                overrideContent(override)
            } else {
                schemaContent
            }
            provenanceContent
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

    /// "Set in `<file>:<line>` / Default: …" block. Always rendered so the
    /// user can tell "this is bundled" from "you (or an include) wrote this"
    /// without leaving the popover.
    @ViewBuilder
    private var provenanceContent: some View {
        let provenance = configStore.provenance(forKey: lookupKey)
        let defaultValue = schemaStore.entry(for: lookupKey)?.defaultValue ?? ""

        if provenance != nil || !defaultValue.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if let provenance {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Set in")
                            .foregroundStyle(.secondary)
                        Button {
                            revealInFinder(provenance.url, line: provenance.line)
                        } label: {
                            Text("\(prettyPath(provenance.url)):\(provenance.line)")
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.link)
                        .help("Reveal in Finder")
                    }
                    .font(.callout)
                } else if !defaultValue.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "circle.dashed")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Using Ghostty's default — not set in your config.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }

                if !defaultValue.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Default")
                            .foregroundStyle(.secondary)
                        Text(defaultValue)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private func prettyPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var path = url.path
        if path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func revealInFinder(_ url: URL, line _: Int) {
        // Finder doesn't natively scroll to a line; revealing the file is the
        // best universal action. Users with text-editor-via-URL setups can
        // grab the path from the label itself.
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
                // Default value moved to the provenance block at the bottom
                // so all "where does this come from" info lives together.
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

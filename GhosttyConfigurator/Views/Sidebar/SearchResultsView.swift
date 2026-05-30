import SwiftUI

/// Sidebar replacement when global search has a query. Renders a flat list
/// of matches grouped by destination pane. Tapping a row navigates to that
/// pane via the provided closure and dismisses the search query.
struct SearchResultsView: View {
    let query: String
    let onSelect: (SearchableRow) -> Void

    private var results: [SearchResult] {
        SearchEngine.results(for: query)
    }

    private var grouped: [(SidebarSection, [SearchResult])] {
        // Preserve the natural sidebar pane order rather than alphabetical.
        let ordered = SidebarSection.visualGroup
            + SidebarSection.behaviorGroup
            + SidebarSection.systemGroup
        return ordered.compactMap { pane in
            let items = results.filter { $0.row.pane == pane }
            return items.isEmpty ? nil : (pane, items)
        }
    }

    var body: some View {
        Group {
            if results.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(grouped, id: \.0) { pane, items in
                        Section {
                            ForEach(items) { result in
                                Button {
                                    onSelect(result.row)
                                } label: {
                                    resultRow(result.row, pane: pane)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(pane.title)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func resultRow(_ row: SearchableRow, pane: SidebarSection) -> some View {
        HStack(spacing: 10) {
            SidebarIcon(symbol: pane.symbol, tint: pane.tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .foregroundStyle(.primary)
                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No results")
                .foregroundStyle(.secondary)
            Text("Try a Ghostty key name or a setting term.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

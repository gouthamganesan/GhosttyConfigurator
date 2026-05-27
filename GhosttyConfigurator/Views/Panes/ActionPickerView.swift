import SwiftUI

/// Searchable list of all Ghostty keybind actions grouped by category.
/// Used as a sheet from the keybind editor — user picks one, sheet dismisses,
/// the parent KeybindEditor updates its action field.
struct ActionPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ActionLabels.Entry) -> Void

    @State private var search: String = ""

    private var filteredEntries: [ActionLabels.Entry] {
        guard !search.isEmpty else { return ActionLabels.catalog }
        return ActionLabels.catalog.filter { entry in
            entry.label.localizedCaseInsensitiveContains(search)
                || entry.verb.localizedCaseInsensitiveContains(search)
                || entry.description.localizedCaseInsensitiveContains(search)
        }
    }

    private var grouped: [(ActionLabels.Category, [ActionLabels.Entry])] {
        let entries = filteredEntries
        return ActionLabels.Category.allCases.compactMap { cat in
            let items = entries.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { category, entries in
                    Section(category.label) {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(entry.label).bold()
                                            if entry.needsParameter {
                                                Text("·").foregroundStyle(.tertiary)
                                                Text("needs parameter")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Text(entry.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(entry.verb)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .searchable(text: $search, placement: .toolbar, prompt: "Search actions")
            .navigationTitle("Choose an action")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 480)
    }
}

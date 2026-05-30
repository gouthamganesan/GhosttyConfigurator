import SwiftUI

struct KeyboardPane: View {
    @Environment(ConfigStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $store.macosOptionAsAlt) {
                        ForEach(MacosOptionAsAlt.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Option as Alt",
                        modified: store.isModified(
                            \.macosOptionAsAlt,
                            default: store.defaults.macosOptionAsAlt
                        ),
                        docKey: "macos-option-as-alt"
                    )
                }

                Toggle(isOn: $store.macosShortcuts) {
                    rowLabel(
                        "macOS menu shortcuts",
                        modified: store.isModified(\.macosShortcuts, default: store.defaults.macosShortcuts),
                        docKey: "macos-shortcuts"
                    )
                }
            } header: {
                Text("macOS modifiers")
            } footer: {
                Text(
                    "**Option as Alt** lets the Option key send Meta/Alt to terminal programs (Vim, Emacs, readline). Off keeps macOS's standard option-character behaviour (option-e → é). **Menu shortcuts** can be disabled if a custom binding collides with a menu item."
                )
            }

            if store.userKeybinds.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No custom shortcuts yet")
                            .foregroundStyle(.secondary)
                        Text(
                            "Ghostty's built-in shortcuts (⌘C copy, ⌘V paste, ⌘⇧, reload config…) work without any configuration. Add a shortcut here to override or extend them."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        NavigationLink(value: KeybindRoute.add) {
                            Text("Add Shortcut")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(store.userKeybinds) { keybind in
                        NavigationLink(value: KeybindRoute.edit(keybind)) {
                            KeybindRow(keybind: keybind)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                store.removeKeybind(keybind)
                            }
                        }
                    }
                } header: {
                    Text("Custom shortcuts")
                } footer: {
                    Text(
                        "Tap a row to edit. Right-click for delete. Custom shortcuts override Ghostty's defaults for the same trigger."
                    )
                }
            }

            Section {
                NavigationLink(value: KeybindRoute.add) {
                    Label("Add Shortcut…", systemImage: "plus")
                }
            }

            if let defaults = store.defaultKeybinds, !defaults.isEmpty {
                DefaultKeybindsSection(keybinds: defaults)
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "Keyboard",
            subtitle: "Custom shortcuts and key bindings."
        )
        .navigationDestination(for: KeybindRoute.self) { route in
            KeybindEditorView(editing: route.editingKeybind) { keybind in
                switch route {
                case .add:
                    store.addKeybind(keybind)
                case let .edit(old):
                    store.replaceKeybind(old, with: keybind)
                }
            }
        }
    }
}

enum KeybindRoute: Hashable {
    case add
    case edit(Keybind)

    var editingKeybind: Keybind? {
        switch self {
        case .add: nil
        case let .edit(k): k
        }
    }
}

// MARK: - Row

private struct KeybindRow: View {
    let keybind: Keybind

    var body: some View {
        HStack(spacing: 14) {
            shortcutChip
                .frame(minWidth: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(actionLabel)
                if !prefixChips.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(prefixChips, id: \.self) { Text($0).font(.caption2) }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !keybind.isSimple {
                Text("Sequence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
            }
        }
        .padding(.vertical, 2)
    }

    private var shortcutChip: some View {
        HStack(spacing: 2) {
            if keybind.isSimple {
                ForEach(keybind.modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })) { mod in
                    Text(mod.glyph)
                }
                Text(displayKey(keybind.key))
                    .textCase(.uppercase)
            } else {
                Text(keybind.rawTrigger)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    private var actionLabel: String {
        let base = ActionLabels.label(for: keybind.action.verb)
        if let param = keybind.action.parameter, !param.isEmpty {
            return "\(base) (\(param))"
        }
        return base
    }

    private var prefixChips: [String] {
        keybind.prefixes
            .sorted { $0.rawValue < $1.rawValue }
            .map { "\($0.rawValue):" }
    }

    private func displayKey(_ key: String) -> String {
        switch key {
        case "up": "↑"
        case "down": "↓"
        case "left": "←"
        case "right": "→"
        case "enter": "↩"
        case "tab": "⇥"
        case "escape": "⎋"
        case "space": "␣"
        case "delete", "backspace": "⌫"
        default: key
        }
    }
}

// MARK: - Built-in (default) keybinds

/// Read-only listing of Ghostty's built-in shortcuts, grouped by action
/// category and collapsed into DisclosureGroups so they don't dominate the
/// pane. Surfaces what the user is overriding when they add a custom row.
private struct DefaultKeybindsSection: View {
    let keybinds: [Keybind]

    var body: some View {
        Section {
            ForEach(groupedCategories, id: \.0) { category, items in
                DisclosureGroup {
                    ForEach(items) { keybind in
                        KeybindRow(keybind: keybind)
                            .padding(.vertical, 2)
                    }
                } label: {
                    HStack {
                        Text(category.label)
                        Spacer()
                        Text("\(items.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Built-in shortcuts")
        } footer: {
            Text(
                "Ghostty's defaults, read from `ghostty +list-keybinds --default`. To override one, add a custom shortcut above with the same trigger."
            )
        }
    }

    /// Stable per-pane category ordering (matches the action picker's display
    /// order). Categories with no entries are dropped.
    private var groupedCategories: [(ActionLabels.Category, [Keybind])] {
        let buckets = Dictionary(grouping: keybinds) { kb in
            ActionLabels.entry(for: kb.action.verb)?.category ?? .custom
        }
        return ActionLabels.Category.allCases.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }
}

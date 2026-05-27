import SwiftUI

struct KeyboardPane: View {
    @Environment(ConfigStore.self) private var store
    @State private var editing: Keybind?
    @State private var showEditor: Bool = false
    @State private var addingNew: Bool = false

    var body: some View {
        Form {
            if store.userKeybinds.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No custom shortcuts yet")
                            .foregroundStyle(.secondary)
                        Text("Ghostty's built-in shortcuts (⌘C copy, ⌘V paste, ⌘⇧, reload config…) work without any configuration. Add a shortcut here to override or extend them.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Add Shortcut") {
                            addingNew = true
                            showEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(store.userKeybinds) { keybind in
                        KeybindRow(keybind: keybind)
                            .contextMenu {
                                Button("Edit") {
                                    editing = keybind
                                    addingNew = false
                                    showEditor = true
                                }
                                Button("Delete", role: .destructive) {
                                    store.removeKeybind(keybind)
                                }
                            }
                            .onTapGesture(count: 2) {
                                editing = keybind
                                addingNew = false
                                showEditor = true
                            }
                    }
                } header: {
                    Text("Custom shortcuts")
                } footer: {
                    Text("Right-click a row to edit or delete. Custom shortcuts override Ghostty's defaults for the same trigger.")
                }
            }

            Section {
                Button {
                    addingNew = true
                    editing = nil
                    showEditor = true
                } label: {
                    Label("Add Shortcut…", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .paneToolbar(title: "Keyboard",
                     subtitle: "Custom shortcuts and key bindings.")
        .sheet(isPresented: $showEditor) {
            KeybindEditorView(editing: addingNew ? nil : editing) { keybind in
                if addingNew {
                    store.addKeybind(keybind)
                } else if let editing {
                    store.replaceKeybind(editing, with: keybind)
                }
            }
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
        case "up":     "↑"
        case "down":   "↓"
        case "left":   "←"
        case "right":  "→"
        case "enter":  "↩"
        case "tab":    "⇥"
        case "escape": "⎋"
        case "space":  "␣"
        case "delete", "backspace": "⌫"
        default:       key
        }
    }
}

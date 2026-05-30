import SwiftUI

struct KeyboardPane: View {
    @Environment(ConfigStore.self) private var store

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

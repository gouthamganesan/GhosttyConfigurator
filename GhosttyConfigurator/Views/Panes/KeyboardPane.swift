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

                LabeledContent {
                    Picker("", selection: $store.macosShortcuts) {
                        ForEach(MacosShortcuts.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                } label: {
                    rowLabel(
                        "Shortcuts.app access",
                        modified: store.isModified(\.macosShortcuts, default: store.defaults.macosShortcuts),
                        docKey: "macos-shortcuts"
                    )
                }
            } header: {
                Text("macOS modifiers")
            } footer: {
                Text(
                    "**Option as Alt** lets the Option key send Meta/Alt to terminal programs (Vim, Emacs, readline). Off keeps macOS's standard option-character behaviour (option-e → é). **Shortcuts.app access** governs whether macOS Shortcuts can drive Ghostty — a powerful but security-sensitive surface; default asks once per request."
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
                Text(KeyDisplay.label(for: keybind.key))
                    .textCase(KeyDisplay.isWord(keybind.key) ? .none : .uppercase)
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
        guard let param = keybind.action.parameter, !param.isEmpty else { return base }
        return "\(base) (\(displayParameter(param, verb: keybind.action.verb)))"
    }

    /// `text:` / `csi:` / `esc:` actions carry config-syntax-escaped payloads
    /// (`\\x05` for the Ctrl-E byte, `\\033` for ESC, etc.). Ghostty's
    /// `+list-keybinds --default` prints them verbatim, so the user sees
    /// `\\x05` which reads as a typo. Collapse `\\` → `\` for display.
    private func displayParameter(_ param: String, verb: String) -> String {
        switch verb.lowercased() {
        case "text", "csi", "esc":
            param.replacingOccurrences(of: #"\\"#, with: #"\"#)
        default:
            param
        }
    }

    private var prefixChips: [String] {
        keybind.prefixes
            .sorted { $0.rawValue < $1.rawValue }
            .map { "\($0.rawValue):" }
    }
}

/// Friendlier rendering for Ghostty's raw key tokens.
///
/// Ghostty's `+list-keybinds --default` emits canonical tokens like `digit_1`,
/// `arrow_left`, `page_up`, `home`, plus word-keys (`copy`, `paste`,
/// `f5`). The chip used to render whatever it received in upper-case — `⌘
/// DIGIT_1`, all-caps `COPY` — which read as bugs to anyone who didn't write
/// the parser. This helper maps tokens to glyphs/digits where possible and
/// flags word-keys so the chip can leave them title-cased.
enum KeyDisplay {
    static func label(for key: String) -> String {
        let lower = key.lowercased()
        if let prefix = ["digit_": "", "kp_": ""].first(where: { lower.hasPrefix($0.key) }) {
            return String(lower.dropFirst(prefix.key.count))
        }
        switch lower {
        case "arrow_up", "up": return "↑"
        case "arrow_down", "down": return "↓"
        case "arrow_left", "left": return "←"
        case "arrow_right", "right": return "→"
        case "page_up": return "⇞"
        case "page_down": return "⇟"
        case "home": return "↖"
        case "end": return "↘"
        case "enter", "return": return "↩"
        case "tab": return "⇥"
        case "escape": return "⎋"
        case "space": return "␣"
        case "delete", "backspace": return "⌫"
        case "forward_delete": return "⌦"
        default:
            // Capitalise multi-letter words so "Copy" reads better than "COPY",
            // and leave single chars / function-key tokens to the textCase
            // modifier upstream.
            if isWord(lower) { return lower.capitalized }
            return key
        }
    }

    /// True when the token should be rendered as a word (e.g. "Copy"), not
    /// upper-cased as a single key.
    static func isWord(_ key: String) -> Bool {
        let lower = key.lowercased()
        // Function keys (`f1`–`f24`) are short tokens but conventionally caps.
        if lower.range(of: #"^f\d{1,2}$"#, options: .regularExpression) != nil {
            return false
        }
        return lower.count > 1 && lower.allSatisfy(\.isLetter)
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
                    // Without this, the Spacer's empty area doesn't register
                    // taps — only the text glyphs do — so clicks on the
                    // right-hand side of the row mysteriously do nothing.
                    .contentShape(Rectangle())
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
    /// order). Categories with no entries are dropped. Within a category we
    /// dedupe by (verb, parameter), keeping the first trigger Ghostty listed —
    /// this folds aliases like ⌘1 / ⌘DIGIT_1 (both `goto_tab:1`) into one row.
    private var groupedCategories: [(ActionLabels.Category, [Keybind])] {
        let deduped = keybinds.deduplicated { kb in
            "\(kb.action.verb)|\(kb.action.parameter ?? "")"
        }
        let buckets = Dictionary(grouping: deduped) { kb in
            ActionLabels.entry(for: kb.action.verb)?.category ?? .custom
        }
        return ActionLabels.Category.allCases.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }
}

private extension Array {
    /// Stable dedup that keeps the first element matching each key.
    func deduplicated<K: Hashable>(by key: (Element) -> K) -> [Element] {
        var seen: Set<K> = []
        var result: [Element] = []
        result.reserveCapacity(count)
        for item in self where seen.insert(key(item)).inserted {
            result.append(item)
        }
        return result
    }
}

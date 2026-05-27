import Foundation

/// A single Ghostty keybinding: trigger + action.
///
/// Configuration form: `keybind = PREFIX:MODIFIER+KEY=ACTION_VERB:PARAM`
/// Examples:
///   `keybind = cmd+c=copy_to_clipboard`
///   `keybind = global:cmd+grave=toggle_quick_terminal`
///   `keybind = ctrl+a>n=new_window`              ← chord sequence (deferred)
///   `keybind = unconsumed:performable:cmd+v=paste_from_clipboard`
///
/// Phase 5 scope: single-chord triggers with prefix support. Chord sequences
/// (the `>` syntax) are parsed but presented to the user as opaque "advanced"
/// rows that the editor doesn't try to modify.
struct Keybind: Hashable, Sendable, Identifiable {
    /// Stable identifier so SwiftUI lists can diff. Uses the trigger string —
    /// trigger uniqueness is enforced by Ghostty itself (later wins).
    var id: String { rawTrigger }

    var prefixes: Set<TriggerPrefix>
    var modifiers: Set<KeyModifier>
    var key: String                 // canonical key name (e.g. "c", "f5", "up")
    /// Original right-hand side of the trigger, preserved for chord sequences
    /// and edge cases the structured fields don't represent. When `isSimple`,
    /// modifiers + key are authoritative.
    var rawTrigger: String

    var action: KeybindAction

    /// True when the trigger is a single chord we can edit structurally
    /// (no `>` chord sequences, no exotic key forms).
    var isSimple: Bool {
        !rawTrigger.contains(">") && !key.isEmpty
    }
}

enum TriggerPrefix: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all
    case global
    case unconsumed
    case performable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:         "All surfaces"
        case .global:      "System-wide (macOS)"
        case .unconsumed:  "Send to app too"
        case .performable: "Only if applicable"
        }
    }
}

enum KeyModifier: String, CaseIterable, Hashable, Sendable, Identifiable {
    case shift, ctrl, alt, cmd

    var id: String { rawValue }

    /// Glyph rendered in shortcut chips — matches macOS HIG.
    var glyph: String {
        switch self {
        case .shift: "⇧"
        case .ctrl:  "⌃"
        case .alt:   "⌥"
        case .cmd:   "⌘"
        }
    }

    /// Canonical config-file token.
    var configToken: String {
        switch self {
        case .shift: "shift"
        case .ctrl:  "ctrl"
        case .alt:   "alt"
        case .cmd:   "cmd"
        }
    }

    /// All token aliases Ghostty accepts; we read them all, emit the canonical.
    static func parse(token: String) -> KeyModifier? {
        switch token.lowercased() {
        case "shift":                     .shift
        case "ctrl", "control":           .ctrl
        case "alt", "opt", "option":      .alt
        case "cmd", "command", "super":   .cmd
        default:                          nil
        }
    }

    /// Sort order for stable rendering (matches macOS convention: ⌃⌥⇧⌘).
    var sortOrder: Int {
        switch self {
        case .ctrl:  0
        case .alt:   1
        case .shift: 2
        case .cmd:   3
        }
    }
}

/// Parsed action: verb + optional parameter. The verb is the canonical
/// snake_case identifier from Ghostty (e.g. `copy_to_clipboard`).
struct KeybindAction: Hashable, Sendable {
    var verb: String
    var parameter: String?           // nil for actions without a param

    /// `verb` or `verb:parameter` — the form Ghostty writes.
    var serialized: String {
        if let parameter, !parameter.isEmpty {
            return "\(verb):\(parameter)"
        }
        return verb
    }

    init(verb: String, parameter: String? = nil) {
        self.verb = verb
        self.parameter = parameter
    }

    /// Parse a `verb` or `verb:param` string.
    init(parsing raw: String) {
        // Split on FIRST `:` since some params (csi, esc, text) may include `:`.
        if let colon = raw.firstIndex(of: ":") {
            self.verb = String(raw[..<colon])
            self.parameter = String(raw[raw.index(after: colon)...])
        } else {
            self.verb = raw
            self.parameter = nil
        }
    }
}

// MARK: - Parser

enum KeybindParser {
    /// Parse a `keybind = …` value into a structured Keybind. Returns nil for
    /// malformed strings (Ghostty would silently ignore them too).
    static func parse(_ value: String) -> Keybind? {
        // Ghostty splits the keybind value on the FIRST `=` — but the value
        // we receive here is already the post-`=` portion. We need to split
        // again on the first `=` inside (which separates trigger from action).
        guard let eq = value.firstIndex(of: "=") else { return nil }

        let triggerRaw = String(value[..<eq]).trimmingCharacters(in: .whitespaces)
        let actionRaw = String(value[value.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        guard !triggerRaw.isEmpty, !actionRaw.isEmpty else { return nil }

        // Pull off any prefixes (PREFIX:...). Multiple can stack.
        var working = triggerRaw
        var prefixes: Set<TriggerPrefix> = []
        while let colon = working.firstIndex(of: ":") {
            let head = String(working[..<colon]).lowercased()
            if let prefix = TriggerPrefix(rawValue: head) {
                prefixes.insert(prefix)
                working = String(working[working.index(after: colon)...])
            } else {
                break
            }
        }

        // Parse the chord (may contain `>` for sequences — we capture rawTrigger
        // but only decompose the first chord into modifiers+key for editing).
        let firstChord: String
        if let arrow = working.firstIndex(of: ">") {
            firstChord = String(working[..<arrow])
        } else {
            firstChord = working
        }

        let parts = firstChord.split(separator: "+").map { String($0) }
        var modifiers: Set<KeyModifier> = []
        var key = ""
        for part in parts {
            if let mod = KeyModifier.parse(token: part) {
                modifiers.insert(mod)
            } else {
                key = part.lowercased()
            }
        }

        return Keybind(
            prefixes: prefixes,
            modifiers: modifiers,
            key: key,
            rawTrigger: working,
            action: KeybindAction(parsing: actionRaw)
        )
    }

    /// Serialize a Keybind back into the value Ghostty writes after `keybind = `.
    /// For non-simple bindings (chord sequences), uses `rawTrigger` verbatim.
    static func serialize(_ keybind: Keybind) -> String {
        let prefixPart: String
        if keybind.prefixes.isEmpty {
            prefixPart = ""
        } else {
            // Stable order: all, global, unconsumed, performable.
            let order: [TriggerPrefix] = [.all, .global, .unconsumed, .performable]
            let tokens = order.filter { keybind.prefixes.contains($0) }.map { $0.rawValue + ":" }
            prefixPart = tokens.joined()
        }

        let triggerPart: String
        if keybind.isSimple && !keybind.rawTrigger.contains(">") {
            // Rebuild from structured fields so user edits land.
            let mods = keybind.modifiers
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { $0.configToken }
            triggerPart = (mods + [keybind.key]).joined(separator: "+")
        } else {
            triggerPart = keybind.rawTrigger
        }

        return "\(prefixPart)\(triggerPart)=\(keybind.action.serialized)"
    }
}

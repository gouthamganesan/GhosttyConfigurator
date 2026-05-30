import AppKit
import SwiftUI

/// Focusable view that captures a single chord (modifiers + key) and reports
/// it back through a binding. When focused, the user's keypress is consumed
/// and decoded into a `(Set<KeyModifier>, String)` pair; when unfocused, the
/// field renders the previously-captured trigger as shortcut glyphs.
struct KeybindTriggerField: View {
    @Binding var modifiers: Set<KeyModifier>
    @Binding var key: String
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 6) {
            if isRecording {
                Text("Press a shortcut…")
                    .foregroundStyle(.secondary)
                    .italic()
            } else if key.isEmpty {
                Text("Click to record")
                    .foregroundStyle(.tertiary)
            } else {
                shortcutGlyphs
            }
            Spacer(minLength: 0)
            if !key.isEmpty, !isRecording {
                Button {
                    modifiers = []
                    key = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isRecording ? Color.accentColor : Color(NSColor.separatorColor),
                    lineWidth: isRecording ? 2 : 0.5
                )
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isRecording = true
        }
        .background(
            KeyEventCatcher(isActive: isRecording) { event in
                guard isRecording else { return false }
                let recorded = decode(event: event)
                if let recorded {
                    modifiers = recorded.modifiers
                    key = recorded.key
                    isRecording = false
                    return true // consume the event
                }
                return false
            }
        )
    }

    // MARK: - Rendering

    private var shortcutGlyphs: some View {
        HStack(spacing: 2) {
            ForEach(modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })) { mod in
                Text(mod.glyph)
                    .font(.system(size: 13, weight: .medium))
            }
            Text(displayKey)
                .font(.system(size: 13, weight: .medium))
                .textCase(.uppercase)
        }
    }

    private var displayKey: String {
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

    // MARK: - Event decoding

    private func decode(event: NSEvent) -> (modifiers: Set<KeyModifier>, key: String)? {
        var mods: Set<KeyModifier> = []
        let flags = event.modifierFlags
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.ctrl) }
        if flags.contains(.option) { mods.insert(.alt) }
        if flags.contains(.command) { mods.insert(.cmd) }

        // Special keys by keyCode → Ghostty name.
        if let special = specialKeyName(for: event.keyCode) {
            return (mods, special)
        }

        // Letters/digits via characters-ignoring-modifiers.
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return nil }
        let key = chars.lowercased()
        // Filter out modifier-only events (e.g. pressing just Shift).
        guard !key.isEmpty, key.count == 1 || key.allSatisfy(\.isLetter) else { return nil }
        return (mods, key)
    }

    private func specialKeyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 36: "enter" // return
        case 48: "tab"
        case 49: "space"
        case 51: "backspace"
        case 53: "escape"
        case 117: "delete" // forward delete
        case 122: "f1"
        case 120: "f2"
        case 99: "f3"
        case 118: "f4"
        case 96: "f5"
        case 97: "f6"
        case 98: "f7"
        case 100: "f8"
        case 101: "f9"
        case 109: "f10"
        case 103: "f11"
        case 111: "f12"
        case 123: "left"
        case 124: "right"
        case 125: "down"
        case 126: "up"
        case 116: "pgup"
        case 121: "pgdn"
        case 115: "home"
        case 119: "end"
        default: nil
        }
    }
}

// MARK: - NSView bridge for key capture

private struct KeyEventCatcher: NSViewRepresentable {
    let isActive: Bool
    let onKey: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? KeyCatcherView else { return }
        view.onKey = onKey
        if isActive {
            view.window?.makeFirstResponder(view)
        }
    }

    private final class KeyCatcherView: NSView {
        var onKey: (NSEvent) -> Bool = { _ in false }
        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            if !onKey(event) { super.keyDown(with: event) }
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            onKey(event)
        }
    }
}

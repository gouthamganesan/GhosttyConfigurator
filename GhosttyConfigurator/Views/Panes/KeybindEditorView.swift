import SwiftUI

/// Sheet for adding a new keybind or editing an existing one. Three rows:
/// trigger capture, action picker, optional parameter. Saving calls back
/// with the constructed Keybind; cancelling discards.
struct KeybindEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// nil when adding new; pre-filled when editing.
    let editing: Keybind?
    let onSave: (Keybind) -> Void

    @State private var modifiers: Set<KeyModifier>
    @State private var key: String
    @State private var prefixes: Set<TriggerPrefix>
    @State private var actionEntry: ActionLabels.Entry?
    @State private var actionParam: String
    @State private var rawActionVerb: String // for verbs not in our catalog
    @State private var showActionPicker = false

    init(editing: Keybind?, onSave: @escaping (Keybind) -> Void) {
        self.editing = editing
        self.onSave = onSave
        _modifiers = State(initialValue: editing?.modifiers ?? [])
        _key = State(initialValue: editing?.key ?? "")
        _prefixes = State(initialValue: editing?.prefixes ?? [])
        _actionEntry = State(initialValue: editing.flatMap { ActionLabels.entry(for: $0.action.verb) })
        _actionParam = State(initialValue: editing?.action.parameter ?? "")
        _rawActionVerb = State(initialValue: editing?.action.verb ?? "")
    }

    private var canSave: Bool {
        !key.isEmpty && (actionEntry != nil || !rawActionVerb.isEmpty)
    }

    private var needsParameter: Bool {
        actionEntry?.needsParameter ?? false
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    KeybindTriggerField(modifiers: $modifiers, key: $key)
                } label: {
                    Text("Trigger")
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Click the field and press the key combination you want to bind.")
            }

            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(actionEntry?.label ?? (rawActionVerb.isEmpty ? "—" : rawActionVerb))
                            .foregroundStyle(actionEntry == nil && rawActionVerb.isEmpty ? .tertiary : .primary)
                        Spacer(minLength: 0)
                        Button("Choose…") { showActionPicker = true }
                    }
                } label: {
                    Text("Action")
                }
                if needsParameter {
                    LabeledContent {
                        TextField("", text: $actionParam, prompt: Text("Required"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                    } label: {
                        Text("Parameter")
                    }
                }
            } header: {
                Text("Action")
            } footer: {
                if let entry = actionEntry {
                    Text(entry.description)
                }
            }

            Section {
                ForEach(TriggerPrefix.allCases) { prefix in
                    Toggle(prefix.label, isOn: Binding(
                        get: { prefixes.contains(prefix) },
                        set: { isOn in
                            if isOn { prefixes.insert(prefix) } else { prefixes.remove(prefix) }
                        }
                    ))
                }
            } header: {
                Text("Options")
            } footer: {
                Text(
                    "Most bindings use no options. `System-wide` requires macOS accessibility permission; `Send to app too` is rare."
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editing == nil ? "Add Shortcut" : "Edit Shortcut")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showActionPicker) {
            ActionPickerView { entry in
                actionEntry = entry
                rawActionVerb = entry.verb
                if !entry.needsParameter { actionParam = "" }
            }
        }
    }

    private func save() {
        let verb = actionEntry?.verb ?? rawActionVerb
        let action = KeybindAction(
            verb: verb,
            parameter: actionParam.isEmpty ? nil : actionParam
        )
        // Rebuild rawTrigger from the structured fields so the serializer
        // produces a clean canonical form.
        let mods = modifiers.sorted { $0.sortOrder < $1.sortOrder }.map(\.configToken)
        let chord = (mods + [key]).joined(separator: "+")

        let keybind = Keybind(
            prefixes: prefixes,
            modifiers: modifiers,
            key: key,
            rawTrigger: chord,
            action: action
        )
        onSave(keybind)
        dismiss()
    }
}

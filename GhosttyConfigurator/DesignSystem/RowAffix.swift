import SwiftUI

/// Trailing decorator placed after every settings-row label:
///   [Label] [validation badge] [mod dot] [info button]
///
/// The validation badge auto-pulls from the ambient `ConfigStore` so panes
/// don't need to wire it manually — pass a `docKey` and the lookup happens
/// here.
///
/// Compose like:
///     LabeledContent {
///         Picker(...)
///     } label: {
///         HStack(spacing: 6) {
///             Text("Theme")
///             RowAffix(modState: ..., docKey: "theme")
///         }
///     }
struct RowAffix: View {
    @Environment(ConfigStore.self) private var store

    let modState: ModState
    let docKey: String?

    var body: some View {
        HStack(spacing: 4) {
            if let docKey, let issue = store.validationIssues[docKey] {
                ValidationBadge(issue: issue)
            }
            ModificationIndicator(state: modState)
            if let docKey {
                DocTooltip(key: docKey)
            }
        }
    }
}

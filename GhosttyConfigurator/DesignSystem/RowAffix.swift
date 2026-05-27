import SwiftUI

/// Trailing decorator placed after every settings-row label:
///   [Label] [mod dot] [info button]
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
    let modState: ModState
    let docKey: String?

    var body: some View {
        HStack(spacing: 4) {
            ModificationIndicator(state: modState)
            if let docKey {
                DocTooltip(key: docKey)
            }
        }
    }
}

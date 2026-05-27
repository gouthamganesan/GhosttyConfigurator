import SwiftUI

enum ModState: Hashable {
    case unchanged
    case modified
}

/// 6pt dot rendered after a row label. Under the auto-save model
/// (`docs/03-ux-principles.md` Principle 2) there's only one "modified" state —
/// no yellow/saved-vs-unsaved distinction.
struct ModificationIndicator: View {
    let state: ModState

    var body: some View {
        Group {
            switch state {
            case .unchanged:
                Color.clear
            case .modified:
                Circle().fill(Color.accentColor)
            }
        }
        .frame(width: 6, height: 6)
        .accessibilityLabel(state == .modified ? "Modified from default" : "")
    }
}

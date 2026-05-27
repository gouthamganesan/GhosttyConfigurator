import SwiftUI

/// Compact wrapper for every pane row's label: text + modification dot +
/// doc-tooltip info button. Reduces boilerplate in pane views.
func rowLabel(_ title: String, modified: Bool, docKey: String?) -> some View {
    HStack(spacing: 6) {
        Text(title)
        RowAffix(
            modState: modified ? .modified : .unchanged,
            docKey: docKey
        )
    }
}

import SwiftUI

/// Phase 1 stand-in for not-yet-implemented panes. Renders a hero card and
/// a single "Coming soon" message so the squint test focuses on Appearance.
struct PlaceholderPane: View {
    let section: SidebarSection

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Text("Coming soon").foregroundStyle(.secondary)
                }
            } footer: {
                Text("This pane is on the roadmap. The visual skeleton is in place; controls land in later phases.")
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: section.title,
            subtitle: "Coming soon."
        )
    }
}

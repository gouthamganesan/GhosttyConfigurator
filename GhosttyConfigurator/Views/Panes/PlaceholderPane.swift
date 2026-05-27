import SwiftUI

/// Phase 1 stand-in for not-yet-implemented panes. Renders a hero card and
/// a single "Coming soon" message so the squint test focuses on Appearance.
struct PlaceholderPane: View {
    let section: SidebarSection

    var body: some View {
        Form {
            Section {
                HeroCard(
                    symbol: section.symbol,
                    title: section.title,
                    description: "This pane is on the roadmap. The visual skeleton is in place; controls land in later phases."
                    , iconGradient: gradient
                )
            }
            Section {
                LabeledContent("Status") {
                    Text("Coming soon").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(section.title)
    }

    private var gradient: [Color] {
        // Pull two adjacent shades from the section tint for the hero icon.
        [section.tint, section.tint.opacity(0.75)]
    }
}

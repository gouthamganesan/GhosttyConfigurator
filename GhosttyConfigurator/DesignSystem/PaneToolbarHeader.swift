import SwiftUI

/// Pane identity rendered as the first content row of every pane.
///
/// Not in the toolbar (the toolbar adds its own frosted material around any
/// items, which creates a visible "oval" that doesn't match the page
/// background). Instead this sits in the content area with the same
/// horizontal padding as the Form sections below it, so it reads as part
/// of the page.
struct PaneHeader: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(tint)
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

extension View {
    /// Sets the navigationTitle so macOS Tahoe lays out the toolbar with
    /// title in the leading slot and `.primaryAction` items on the trailing
    /// edge — that's the only reliable way to right-align the reload button
    /// on macOS NavigationSplitView. The title text itself is hidden by the
    /// window's `titleVisibility = .hidden` so no duplicate appears in the
    /// title bar; the visible header is rendered inside the Form by the
    /// pane itself.
    func paneToolbar(title: String, subtitle: String) -> some View {
        navigationTitle(title)
            .navigationSubtitle(subtitle)
    }
}

/// Section row used as the first row of each pane's Form. Renders with a
/// transparent row background and no separator so it merges with the page
/// background, and scrolls with the rest of the Form's content (not pinned).
struct PaneHeaderRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        PaneHeader(symbol: symbol, title: title, subtitle: subtitle, tint: tint)
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 12, trailing: 4))
    }
}


import SwiftUI

/// Compact pane identity rendered as a `ToolbarItem(placement: .principal)`.
/// Replaces the larger HeroCard section that used to sit at the top of each
/// Form. Icon + title + subtitle on a single line, with no background tint —
/// merges with the window's natural toolbar material.
struct PaneToolbarHeader: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
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
        }
    }
}

extension View {
    /// Adds the compact pane header to the toolbar's principal slot.
    /// Use instead of `HeroCard` at the top of a pane's Form.
    func paneToolbar(symbol: String,
                     title: String,
                     subtitle: String,
                     tint: Color) -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                PaneToolbarHeader(symbol: symbol, title: title, subtitle: subtitle, tint: tint)
            }
        }
    }
}

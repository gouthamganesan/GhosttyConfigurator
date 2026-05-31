import SwiftUI

/// Compact tile shown in the theme grid: 16-swatch palette + bg/fg sample.
/// Tap selects; the selected tile gets an accent ring.
struct ThemeTile: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                preview
                Text(theme.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color(NSColor.separatorColor),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Theme: \(theme.name). \(theme.palette.count) colors.\(isSelected ? " Selected." : "")")
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 4) {
                paletteStrip
                sampleText
            }
            .padding(8)
        }
        .frame(height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var background: some View {
        Rectangle()
            .fill(ColorParsing.color(from: theme.background) ?? Color.black)
    }

    private var paletteStrip: some View {
        HStack(spacing: 1) {
            ForEach(0 ..< 16, id: \.self) { idx in
                Rectangle()
                    .fill(ColorParsing.color(from: theme.palette[idx]) ?? Color.gray)
                    .frame(height: 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private var sampleText: some View {
        Text("$ ls -la")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(ColorParsing.color(from: theme.foreground) ?? Color.white)
    }
}

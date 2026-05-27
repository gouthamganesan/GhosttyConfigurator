import SwiftUI

/// Faux-terminal preview rendered with a theme's actual palette. Mirrors what
/// `bat`/`ls --color` output looks like, not an IDE editor.
///
/// Used in the theme browser detail and (later) Font / Cursor panes.
struct TerminalPreview: View {
    let theme: Theme
    var fontSize: Double = 12

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 2) {
                prompt(cwd: "~/projects/ghostty", command: "ls -la")
                listing
                blank
                prompt(cwd: "~/projects/ghostty", command: "cat README.md")
                codeBlock
                cursorLine
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: - Sections

    private var background: some View {
        Rectangle().fill(bg)
    }

    private func prompt(cwd: String, command: String, error: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(error ? "✗ " : "❯ ")
                .foregroundStyle(error ? color(1) : color(2))
            Text("\(cwd) ")
                .foregroundStyle(color(4))
            Text(command)
                .foregroundStyle(fg)
        }
        .font(termFont)
    }

    private var listing: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("drwxr-xr-x  6 you  staff   192 May 27 09:00 ")
                .foregroundStyle(color(8)) +
                Text(".")
                    .foregroundStyle(color(4))
            Text("-rw-r--r--  1 you  staff  1.2K May 27 09:00 ")
                .foregroundStyle(color(8)) +
                Text("README.md")
                    .foregroundStyle(fg)
            Text("-rwxr-xr-x  1 you  staff   24K May 27 09:00 ")
                .foregroundStyle(color(8)) +
                Text("build.sh")
                    .foregroundStyle(color(2))
        }
        .font(termFont)
    }

    private var codeBlock: some View {
        // bat-style highlighting: heading=blue, string=yellow, comment=green.
        VStack(alignment: .leading, spacing: 1) {
            (Text("# ").foregroundStyle(color(4)) +
             Text("Ghostty Configurator").foregroundStyle(fg).bold())
            Text("Native macOS GUI for Ghostty config.")
                .foregroundStyle(fg)
            Text("> Status: ").foregroundStyle(color(2)) +
                Text("Phase 4 — theme browser").foregroundStyle(color(3))
        }
        .font(termFont)
    }

    private var errorLine: some View {
        Text("error: cannot find 'undefined' in scope")
            .foregroundStyle(color(1))
            .font(termFont)
    }

    private var cursorLine: some View {
        HStack(spacing: 0) {
            Text("❯ ")
                .foregroundStyle(color(2))
            Text("")
                .foregroundStyle(fg)
            Rectangle()
                .fill(cursor)
                .frame(width: 8, height: CGFloat(fontSize + 1))
        }
        .font(termFont)
    }

    private var blank: some View {
        Color.clear.frame(height: 4)
    }

    // MARK: - Color helpers

    private var bg: Color { ColorParsing.color(from: theme.background) ?? .black }
    private var fg: Color { ColorParsing.color(from: theme.foreground) ?? .white }
    private var cursor: Color {
        if let c = theme.cursorColor { return ColorParsing.color(from: c) ?? fg }
        return fg
    }

    private func color(_ idx: Int) -> Color {
        ColorParsing.color(from: theme.palette[idx]) ?? fg
    }

    private var termFont: Font {
        .system(size: fontSize, design: .monospaced)
    }
}

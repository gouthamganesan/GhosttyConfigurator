import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case appearance
    case window
    case font
    case cursor

    case keyboard
    case shell
    case clipboardMouse
    case general

    case advanced
    case about

    var id: String { rawValue }

    // MARK: - Grouping (rendered as three separate List sections)

    static let visualGroup: [SidebarSection]   = [.appearance, .window, .font, .cursor]
    static let behaviorGroup: [SidebarSection] = [.keyboard, .shell, .clipboardMouse, .general]
    static let systemGroup: [SidebarSection]   = [.advanced, .about]

    // MARK: - Display metadata

    var title: String {
        switch self {
        case .appearance:     "Appearance"
        case .window:         "Window"
        case .font:           "Font"
        case .cursor:         "Cursor"
        case .keyboard:       "Keyboard"
        case .shell:          "Shell"
        case .clipboardMouse: "Clipboard & Mouse"
        case .general:        "General"
        case .advanced:       "Advanced"
        case .about:          "About"
        }
    }

    var symbol: String {
        switch self {
        case .appearance:     "paintpalette.fill"
        case .window:         "macwindow"
        case .font:           "textformat"
        case .cursor:         "cursorarrow.rays"
        case .keyboard:       "keyboard.fill"
        case .shell:          "terminal.fill"
        case .clipboardMouse: "doc.on.clipboard.fill"
        case .general:        "gearshape.fill"
        case .advanced:       "slider.horizontal.3"
        case .about:          "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .appearance:     .pink
        case .window:         .blue
        case .font:           .indigo
        case .cursor:         .teal
        case .keyboard:       Color(NSColor.systemGray)
        case .shell:          Color(NSColor.systemGray)
        case .clipboardMouse: .green
        case .general:        Color(NSColor.systemGray)
        case .advanced:       .orange
        case .about:          .blue
        }
    }
}

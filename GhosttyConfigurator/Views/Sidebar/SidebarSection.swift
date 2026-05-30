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

    var id: String {
        rawValue
    }

    // MARK: - Grouping (rendered as separate List sections, in order)

    //
    // `general` sits alone at the top — it's the macOS System Settings idiom
    // for the catch-all section (lifecycle, updates, notifications), and the
    // user explicitly requested it not be lumped with the behaviour group.

    static let generalGroup: [SidebarSection] = [.general]
    static let visualGroup: [SidebarSection] = [.appearance, .window, .font, .cursor]
    static let behaviorGroup: [SidebarSection] = [.keyboard, .shell, .clipboardMouse]
    static let systemGroup: [SidebarSection] = [.advanced, .about]

    // MARK: - Display metadata

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .window: "Window"
        case .font: "Font"
        case .cursor: "Cursor"
        case .keyboard: "Keyboard"
        case .shell: "Shell"
        case .clipboardMouse: "Clipboard & Mouse"
        case .general: "General"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .appearance: "paintpalette.fill"
        case .window: "macwindow"
        case .font: "textformat"
        case .cursor: "cursorarrow.rays"
        case .keyboard: "keyboard.fill"
        case .shell: "terminal.fill"
        case .clipboardMouse: "doc.on.clipboard.fill"
        case .general: "gearshape.fill"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle.fill"
        }
    }

    /// Tints per `docs/02-information-architecture.md`. Greys are kept for
    /// genuinely catch-all rows (Shell, General, About — utilitarian); the
    /// expressive panes get System Settings-style accent colours.
    var tint: Color {
        switch self {
        case .appearance: .purple
        case .window: .blue
        case .font: .pink
        case .cursor: .orange
        case .keyboard: .indigo
        case .shell: Color(NSColor.systemGray)
        case .clipboardMouse: .cyan
        case .general: Color(NSColor.systemGray)
        case .advanced: Color(NSColor.systemGray)
        case .about: .blue
        }
    }
}

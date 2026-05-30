import Foundation
import SwiftUI

/// A parsed Ghostty theme — palette + bg/fg + selection + cursor colors.
/// The theme name doubles as the value written to `theme = …` in the config.
struct Theme: Hashable, Identifiable {
    let name: String
    let sourceURL: URL
    let source: ThemeSource

    /// 16 ANSI colors, indexed 0…15. Always exactly 16 entries (missing
    /// indices fall back to black so consumers can index safely).
    let palette: [String]
    let background: String
    let foreground: String
    let cursorColor: String?
    let cursorText: String?
    let selectionBackground: String?
    let selectionForeground: String?

    var id: String {
        name
    }

    /// Background-luminance bucket. Themes whose `background` luminance is
    /// below 0.5 are considered dark. Drives the Light / Dark filter chips.
    var isDark: Bool {
        ColorParsing.isDark(background) ?? false
    }
}

enum ThemeSource: Hashable {
    case bundled // shipped inside Ghostty.app
    case user // user-installed (~/.config or AppSupport)

    var label: String {
        switch self {
        case .bundled: "Bundled"
        case .user: "User"
        }
    }
}

/// Lightweight reference used while enumerating themes — name + URL only,
/// no parse cost. The browser loads the full `Theme` on demand.
struct ThemeRef: Hashable, Identifiable {
    let name: String
    let url: URL
    let source: ThemeSource

    var id: String {
        name
    }
}

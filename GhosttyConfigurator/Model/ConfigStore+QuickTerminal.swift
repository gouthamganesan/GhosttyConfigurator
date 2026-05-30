import Foundation

/// A3b — Quick Terminal accessors. Slide-out drop-down terminal that
/// Ghostty exposes via the `toggle_quick_terminal` keybind action.
/// Pure forwarding to the same scalar/enum helpers the rest of the store
/// uses; kept in a separate file so `ConfigStore.swift` stays under the
/// SwiftLint file-length cap.
@MainActor
extension ConfigStore {
    var quickTerminalPosition: QuickTerminalPosition {
        get {
            file.enumValue(
                QuickTerminalPosition.self,
                for: "quick-terminal-position",
                default: .top
            )
        }
        set { setEnum("quick-terminal-position", newValue, label: "Change Quick Terminal Position") }
    }

    var quickTerminalScreen: QuickTerminalScreen {
        get { file.enumValue(QuickTerminalScreen.self, for: "quick-terminal-screen", default: .main) }
        set { setEnum("quick-terminal-screen", newValue, label: "Change Quick Terminal Screen") }
    }

    var quickTerminalSpaceBehavior: QuickTerminalSpaceBehavior {
        get {
            file.enumValue(
                QuickTerminalSpaceBehavior.self,
                for: "quick-terminal-space-behavior",
                default: .move
            )
        }
        set { setEnum("quick-terminal-space-behavior", newValue, label: "Change Quick Terminal Space Behaviour") }
    }

    /// `quick-terminal-animation-duration` — seconds; 0 disables animation.
    /// Stored as Double; clamps to [0, 2] in the UI since longer values
    /// degrade the slide-down UX.
    var quickTerminalAnimationDuration: Double {
        get { file.double(for: "quick-terminal-animation-duration", default: 0.2) }
        set { setDouble("quick-terminal-animation-duration", newValue, label: "Change Quick Terminal Animation") }
    }

    var quickTerminalAutohide: Bool {
        get { file.bool(for: "quick-terminal-autohide", default: true) }
        set { setBool("quick-terminal-autohide", newValue, label: "Toggle Quick Terminal Autohide") }
    }
}

import AppKit
import SwiftUI

/// Presents the shared `NSFontPanel` and feeds the selected font name back
/// into a SwiftUI binding. Internally maintains a small AppKit target so the
/// font panel's "change font" message has somewhere to land.
@MainActor
final class FontPickerCoordinator: NSObject {
    static let shared = FontPickerCoordinator()

    private var onSelect: ((NSFont) -> Void)?

    /// Show the font panel pre-filled with `currentFont`. The closure fires
    /// every time the user picks something in the panel.
    func present(currentFont: NSFont, onSelect: @escaping (NSFont) -> Void) {
        self.onSelect = onSelect

        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeFont(_:))
        manager.setSelectedFont(currentFont, isMultiple: false)

        // Show only monospace-family choices — terminals don't care about prose fonts.
        // Set the panel's accessory if needed. For simplicity we present the unfiltered
        // panel; users can use macOS's "Fixed Width" filter in the panel.
        let panel = NSFontPanel.shared
        panel.makeKeyAndOrderFront(nil)
    }

    @objc
    private func changeFont(_ sender: NSFontManager?) {
        guard let manager = sender else { return }
        let current = NSFont.systemFont(ofSize: 13)
        let new = manager.convert(current)
        onSelect?(new)
    }
}

/// SwiftUI wrapper: a Button that opens NSFontPanel with the current family,
/// writes the picked family back through the binding.
struct FontPickerButton: View {
    let currentFamily: String
    let currentSize: Double
    let onPick: (String, Double) -> Void

    var body: some View {
        Button("Choose…") {
            // Best-effort resolve of the current font. If the named family
            // isn't installed, fall back to the system monospaced font so
            // the panel still opens at a sensible starting point.
            let font = NSFont(name: currentFamily, size: currentSize)
                ?? .monospacedSystemFont(ofSize: currentSize, weight: .regular)
            FontPickerCoordinator.shared.present(currentFont: font) { picked in
                let familyName = picked.familyName ?? picked.fontName
                onPick(familyName, Double(picked.pointSize))
            }
        }
    }
}

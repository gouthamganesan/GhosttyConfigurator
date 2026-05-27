import SwiftUI

/// Parse Ghostty's color literal forms into a SwiftUI `Color`.
///
/// Ghostty accepts:
///   `#RRGGBB`, `RRGGBB`, `#RGB`, `RGB`
/// — case-insensitive, optional `#`. No named colors in the theme format.
enum ColorParsing {
    /// Parse a hex color string. Returns nil if the input doesn't conform —
    /// callers should fall back to a default rather than crash.
    static func color(from raw: String) -> Color? {
        guard let rgb = rgbComponents(from: raw) else { return nil }
        return Color(.sRGB,
                     red: Double(rgb.r) / 255.0,
                     green: Double(rgb.g) / 255.0,
                     blue: Double(rgb.b) / 255.0,
                     opacity: 1.0)
    }

    /// Decompose into 0…255 RGB triple. Useful for luminance calculations
    /// (the `isDark` heuristic on `Theme`).
    static func rgbComponents(from raw: String) -> (r: Int, g: Int, b: Int)? {
        var body = raw.trimmingCharacters(in: .whitespaces)
        if body.hasPrefix("#") { body.removeFirst() }
        guard body.allSatisfy(\.isHexDigit) else { return nil }

        // Expand short form `RGB` → `RRGGBB`.
        if body.count == 3 {
            body = body.map { "\($0)\($0)" }.joined()
        }
        guard body.count == 6 else { return nil }

        guard
            let r = Int(body.prefix(2), radix: 16),
            let g = Int(body.dropFirst(2).prefix(2), radix: 16),
            let b = Int(body.dropFirst(4).prefix(2), radix: 16)
        else { return nil }
        return (r, g, b)
    }

    /// Perceived-luminance "is this color dark?" check using the standard
    /// Rec. 601 luma formula. Used to bucket themes into Light / Dark for the
    /// browser filter chips.
    static func isDark(_ raw: String) -> Bool? {
        guard let (r, g, b) = rgbComponents(from: raw) else { return nil }
        let luma = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255.0
        return luma < 0.5
    }
}

import SwiftUI

/// Semantic color and font aliases. Never hardcode hex anywhere else.
enum Tokens {
    // MARK: - Brand

    /// Brand accent — `#0891B2` (deep cyan/teal). Resolved from the asset
    /// catalog; keep the `Color.accentColor` reference here so accidental
    /// `Color.accentColor` usage in views still produces the right shade.
    static let brandAccent = Color.accentColor
}

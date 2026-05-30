import SwiftUI

/// Semantic color and font aliases. Never hardcode hex anywhere else.
enum Tokens {
    // MARK: - Brand

    /// Brand accent — `#2563EB` (deep blue). Resolved from the asset
    /// catalog; keep the `Color.accentColor` reference here so accidental
    /// `Color.accentColor` usage in views still produces the right shade.
    static let brandAccent = Color.accentColor
}

import SwiftUI

/// Semantic color and font aliases. Never hardcode hex anywhere else.
enum Tokens {
    // MARK: - Brand

    /// Brand accent (the cyan from the logo). Resolved from the asset catalog;
    /// keep the `Color("AccentColor")` reference here so accidental Color.accentColor
    /// usage in views still produces the right shade.
    static let brandAccent = Color.accentColor
}

import Foundation

/// One problem flagged by the validator. The message appears as a hover/click
/// tooltip on a yellow triangle attached to the row.
struct ValidationIssue: Hashable {
    enum Severity { case warning, error }

    let severity: Severity
    let message: String
}

import Foundation

/// One problem flagged by the validator. The message appears as a hover/click
/// tooltip on a yellow triangle attached to the row.
struct ValidationIssue: Hashable, Sendable {
    enum Severity: Sendable { case warning, error }

    let severity: Severity
    let message: String
}

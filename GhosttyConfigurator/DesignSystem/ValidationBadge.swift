import SwiftUI

/// Yellow triangle (or red dot) shown after a row label when the validator
/// flags an issue. Hover/long-press surfaces the message via a popover.
struct ValidationBadge: View {
    let issue: ValidationIssue

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .help(issue.message)
        .accessibilityLabel("\(titleText): \(issue.message)")
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: symbolName).foregroundStyle(tint)
                    Text(titleText).font(.headline)
                }
                Text(issue.message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: 320)
        }
    }

    private var symbolName: String {
        switch issue.severity {
        case .warning: "exclamationmark.triangle.fill"
        case .error: "exclamationmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch issue.severity {
        case .warning: .yellow
        case .error: .red
        }
    }

    private var titleText: String {
        switch issue.severity {
        case .warning: "Heads up"
        case .error: "Invalid value"
        }
    }
}

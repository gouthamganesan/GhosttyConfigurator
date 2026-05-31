import SwiftUI

/// Reusable inline notice, modelled on `InstallBanner`. Use for pane-level
/// warnings (e.g. the schema-catalog fallback) and transient toasts (the
/// file-watch conflict notice). Generic on `kind` (icon + tint), an optional
/// detail line, an optional trailing action button, and an optional dismiss.
struct Banner: View {
    enum Kind {
        case warning
        case info

        var symbol: String {
            switch self {
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .warning: .orange
            case .info: Tokens.brandAccent
            }
        }
    }

    let kind: Kind
    let title: String
    var detail: String?
    /// Optional trailing action — label + handler.
    var actionTitle: String?
    var action: (() -> Void)?
    /// When set, renders a trailing ✕ that flips this binding.
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).bold()
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(kind.tint.opacity(0.12))
        .overlay(
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

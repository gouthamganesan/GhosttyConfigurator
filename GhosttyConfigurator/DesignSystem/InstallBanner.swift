import SwiftUI

/// Yellow banner shown above the pane content when `/Applications/Ghostty.app`
/// isn't installed. The configurator works without Ghostty (you can still
/// author a config), but reload and schema introspection require it.
struct InstallBanner: View {
    @Binding var isDismissed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ghostty isn't installed.")
                    .font(.subheadline).bold()
                Text("You can still edit your config here, but to apply changes you'll need to install Ghostty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Link(destination: URL(string: "https://ghostty.org")!) {
                Text("Download")
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                isDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

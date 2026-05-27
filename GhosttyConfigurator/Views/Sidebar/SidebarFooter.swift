import SwiftUI

/// App-identity footer pinned to the bottom of the sidebar.
/// Logo on the left (squircle), two-line name on the right.
struct SidebarFooter: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text("Ghostty")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Configurator")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Divider()
        }
        .background(.bar)
    }
}

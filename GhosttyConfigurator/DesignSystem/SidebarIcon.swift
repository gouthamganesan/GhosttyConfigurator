import SwiftUI

/// 20×20 squircle tile that holds a white SF Symbol — the System Settings
/// sidebar icon shape. No gradients, no shadows.
struct SidebarIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(tint)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

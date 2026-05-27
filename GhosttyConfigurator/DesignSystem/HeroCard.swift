import SwiftUI

/// The first row of every pane: large gradient icon + title + description.
/// Lives inside its own header-less `Section`; that's what gives it the rounded
/// grouped background.
struct HeroCard: View {
    let symbol: String
    let title: String
    let description: String
    let iconGradient: [Color]

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: iconGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2).bold()
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

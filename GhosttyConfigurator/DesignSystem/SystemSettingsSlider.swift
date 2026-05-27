import SwiftUI

/// Slider with labels *under* the track ends — the System Settings layout.
/// The built-in `Slider(value:in:minimumValueLabel:maximumValueLabel:)` puts
/// labels inline with the track, which looks wrong in a grouped form.
struct SystemSettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let leadingLabel: String
    let trailingLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(value: $value, in: range)
            HStack {
                Text(leadingLabel)
                Spacer()
                Text(trailingLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

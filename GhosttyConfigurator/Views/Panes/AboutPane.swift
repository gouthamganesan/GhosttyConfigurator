import SwiftUI

struct AboutPane: View {
    private let docsLinks: [(String, String)] = [
        ("Ghostty website",               "https://ghostty.org"),
        ("Configuration docs",            "https://ghostty.org/docs/config"),
        ("Full option reference",         "https://ghostty.org/docs/config/reference"),
        ("Keybindings reference",         "https://ghostty.org/docs/config/keybind"),
        ("Keybind actions reference",     "https://ghostty.org/docs/config/keybind/reference"),
        ("Trigger sequences (chords)",    "https://ghostty.org/docs/config/keybind/sequence"),
        ("Themes (community)",            "https://github.com/ghostty-org/ghostty/tree/main/src/config/themes"),
        ("Ghostty source code",           "https://github.com/ghostty-org/ghostty"),
        ("Report a Ghostty issue",        "https://github.com/ghostty-org/ghostty/issues")
    ]

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ghostty Configurator").font(.title2).bold()
                        Text("Version 0.1.0 — Phase 1 preview")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("A native macOS companion to the Ghostty terminal.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }

            Section {
                ForEach(docsLinks, id: \.0) { label, urlString in
                    if let url = URL(string: urlString) {
                        Link(label, destination: url)
                    }
                }
            } header: {
                Text("Documentation")
            } footer: {
                Text("Every external link opens in your default browser.")
            }

            Section {
                Link("Configurator source", destination: URL(string: "https://github.com/")!)
                Link("Report a configurator issue", destination: URL(string: "https://github.com/")!)
            } header: {
                Text("This app")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }
}

#Preview {
    NavigationStack { AboutPane() }
}

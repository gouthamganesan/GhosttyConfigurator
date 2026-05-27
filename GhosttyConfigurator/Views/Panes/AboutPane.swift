import SwiftUI

struct AboutPane: View {
    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let marketing = dict?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(marketing) (\(build))"
    }

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
        .paneToolbar(title: "About",
                     subtitle: "Version \(appVersion)")
    }
}

#Preview {
    NavigationStack { AboutPane() }
}

import AppKit
import SwiftUI

struct AboutPane: View {
    @Environment(ConfigStore.self) private var store

    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Ghostty Configurator"
    }

    private var marketingVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    private var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }

    private var prettyConfigPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var path = store.fileURL.path
        if path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }
        return path
    }

    private var ghosttyVersionLine: String? {
        guard let version = store.ghosttyVersion, !version.isEmpty else { return nil }
        return "Ghostty \(version) installed"
    }

    private let docsLinks: [(String, String)] = [
        ("Ghostty website", "https://ghostty.org"),
        ("Configuration docs", "https://ghostty.org/docs/config"),
        ("Full option reference", "https://ghostty.org/docs/config/reference"),
        ("Keybindings reference", "https://ghostty.org/docs/config/keybind"),
        ("Keybind actions reference", "https://ghostty.org/docs/config/keybind/reference"),
        ("Trigger sequences (chords)", "https://ghostty.org/docs/config/keybind/sequence"),
        ("Themes (community)", "https://github.com/ghostty-org/ghostty/tree/main/src/config/themes"),
        ("Ghostty source code", "https://github.com/ghostty-org/ghostty"),
        ("Report a Ghostty issue", "https://github.com/ghostty-org/ghostty/issues")
    ]

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    Text(appName)
                        .font(.title)
                        .bold()

                    Text("Version \(marketingVersion) (\(buildNumber))")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let ghosttyVersionLine {
                        Text(ghosttyVersionLine)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)
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
                LabeledContent {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active config file")
                        Text(prettyConfigPath)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Button("Open in editor") {
                    store.openActiveConfig()
                }

                Link("Configurator source", destination: URL(string: "https://github.com/")!)
                Link("Report a configurator issue", destination: URL(string: "https://github.com/")!)
            } header: {
                Text("This app")
            }
        }
        .formStyle(.grouped)
        .paneToolbar(
            title: "About",
            subtitle: "Version \(marketingVersion) (\(buildNumber))"
        )
    }
}

#Preview {
    NavigationStack { AboutPane() }
        .environment(ConfigStore())
}

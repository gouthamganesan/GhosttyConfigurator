import Foundation

/// Resolution of Ghostty config file paths per
/// `docs/research-ghostty-config.md` §1.1.
enum ConfigPaths {
    /// All paths Ghostty looks at, in load order (later overrides earlier).
    /// Some may not exist on disk; the configurator should still surface them.
    static func searchPaths() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let xdgRoot: URL = {
            if let custom = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
               !custom.isEmpty
            {
                return URL(fileURLWithPath: custom)
            }
            return home.appendingPathComponent(".config")
        }()

        return [
            xdgRoot.appendingPathComponent("ghostty/config.ghostty"),
            xdgRoot.appendingPathComponent("ghostty/config"),
            home.appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/config.ghostty"),
            home.appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/config")
        ]
    }

    /// The canonical write location: macOS Application Support. Falls back to
    /// the first existing search-path file if Application Support is unwritable.
    static func defaultWriteURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(
            "Library/Application Support/com.mitchellh.ghostty/config.ghostty"
        )
    }

    /// First search-path that actually exists on disk, or `defaultWriteURL()`
    /// if none do. The configurator uses this to decide which file to open
    /// on first launch.
    static func resolveExistingURL() -> URL {
        let fm = FileManager.default
        for url in searchPaths() where fm.fileExists(atPath: url.path) {
            return url
        }
        return defaultWriteURL()
    }

    /// `/Applications/Ghostty.app` if present, else nil. Used to gate the
    /// "Install Ghostty to apply changes" banner and the schema-introspection
    /// shell-out.
    static func ghosttyAppURL() -> URL? {
        let url = URL(fileURLWithPath: "/Applications/Ghostty.app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The `ghostty` CLI inside the app bundle, if present.
    static func ghosttyCLIURL() -> URL? {
        ghosttyAppURL()?.appendingPathComponent("Contents/MacOS/ghostty")
    }
}

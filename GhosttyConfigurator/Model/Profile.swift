import Foundation

/// One row in the Advanced → Profiles list. Wraps an `config-file = ?path`
/// include with display-ready metadata: friendly name, resolved URL, whether
/// the file actually exists on disk, and the optional flag (`?`) — which
/// Ghostty uses to mean "skip silently if missing".
///
/// Profiles are the configurator's headline differentiator: stacking
/// includes lets users switch between work/personal/CTF setups without
/// hand-editing the base config.
struct Profile: Identifiable, Hashable {
    /// `rawPath` from the config (unresolved, may be `~/…` or relative).
    let rawPath: String
    let isOptional: Bool
    let lineNumber: Int

    var id: String {
        // Line + raw path uniquely identifies a row even when two includes
        // share the same path (Ghostty allows the same file to be included
        // twice — later wins).
        "\(lineNumber):\(rawPath)"
    }

    /// Resolved absolute URL — expands `~/` to the home directory and
    /// resolves relative paths against the parent config file's directory.
    func resolvedURL(relativeTo parent: URL) -> URL {
        var path = rawPath
        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            path = home + String(path.dropFirst(1))
        }
        if (path as NSString).isAbsolutePath {
            return URL(fileURLWithPath: path)
        }
        return parent.deletingLastPathComponent().appendingPathComponent(path)
    }

    /// Display name — filename without extension. Falls back to the raw path
    /// if the filename is empty (degenerate cases like `config-file = ?`).
    var displayName: String {
        let last = (rawPath as NSString).lastPathComponent
        let stem = (last as NSString).deletingPathExtension
        return stem.isEmpty ? rawPath : stem
    }
}

import AppKit
import Foundation

/// A3a — Profile management. Read + mutate `config-file = ?path` includes.
///
/// The configurator treats includes as profiles: each row is a stackable
/// overlay on the base config (work, personal, CTF, etc). Ghostty applies
/// them in the order they appear, with later writes overriding earlier
/// ones — so the on-disk ordering is the user-visible priority.
@MainActor
extension ConfigStore {
    /// Every active `config-file = ?path` include, in source order.
    /// Disabled includes (comment lines) aren't surfaced today — the
    /// "Remove" gesture deletes them outright; reverting reuses Add.
    var profiles: [Profile] {
        file.includes().map { include in
            Profile(
                rawPath: include.path,
                isOptional: include.isOptional,
                lineNumber: include.lineNumber
            )
        }
    }

    /// Add a new `config-file = ?path` include at the end of the active
    /// config. Always written with the `?` flag so a missing file doesn't
    /// break Ghostty startup. No-op if the same path already appears.
    func addProfile(at path: String) {
        let normalised = path.trimmingCharacters(in: .whitespaces)
        guard !normalised.isEmpty else { return }
        let alreadyIncluded = profiles.contains { $0.rawPath == normalised }
        guard !alreadyIncluded else { return }

        let prior = file.parsed
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceParsedConfig(prior, label: "Remove Profile")
            }
        }
        undoManager?.setActionName("Add Profile")
        mutateFile { file in
            file.parsed.entries.append(.include(.init(
                path: normalised,
                isOptional: true,
                raw: ConfigParser.formatInclude(path: normalised, isOptional: true),
                lineNumber: file.parsed.entries.count + 1
            )))
        }
        schedulePersist()
    }

    /// Remove the include at this line number (which identifies the row even
    /// when two profiles share the same path).
    func removeProfile(_ profile: Profile) {
        let prior = file.parsed
        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceParsedConfig(prior, label: "Restore Profile")
            }
        }
        undoManager?.setActionName("Remove Profile")
        mutateFile { file in
            file.parsed.entries.removeAll { entry in
                if case let .include(inc) = entry,
                   inc.lineNumber == profile.lineNumber,
                   inc.path == profile.rawPath
                {
                    return true
                }
                return false
            }
        }
        schedulePersist()
    }

    /// Move an include up or down in the load order. Last-writer-wins on
    /// scalar keys, so this is the user's lever for "which profile takes
    /// precedence".
    func moveProfile(_ profile: Profile, direction: ProfileMoveDirection) {
        let prior = file.parsed
        let entries = file.parsed.entries
        guard let idx = entries.firstIndex(where: { entry in
            if case let .include(inc) = entry,
               inc.lineNumber == profile.lineNumber,
               inc.path == profile.rawPath
            {
                return true
            }
            return false
        }) else { return }

        // Find the neighbour include we'll swap with — non-include entries
        // (blanks, comments, kvs) between us shouldn't change order.
        let otherIdx: Int? = switch direction {
        case .up:
            (0 ..< idx).reversed().first { entries[$0].isInclude }
        case .down:
            ((idx + 1) ..< entries.count).first { entries[$0].isInclude }
        }
        guard let otherIdx else { return }

        undoManager?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.replaceParsedConfig(prior, label: "Move Profile")
            }
        }
        undoManager?.setActionName("Move Profile")
        var mutated = entries
        mutated.swapAt(idx, otherIdx)
        mutateFile { file in
            file.parsed.entries = mutated
        }
        schedulePersist()
    }

    /// Create a new empty profile file alongside the active config. Returns
    /// the URL the user can drag into `addProfile(at:)` (the caller does the
    /// add — we keep file creation and config mutation separate so the user
    /// can opt out at the last step if they'd rather edit first).
    func createEmptyProfile(named name: String) throws -> URL {
        let dir = fileURL.deletingLastPathComponent().appendingPathComponent("profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name).appendingPathExtension("ghostty")
        if !FileManager.default.fileExists(atPath: url.path) {
            let stub = "# \(name).ghostty\n# Created by GhosttyConfigurator\n"
            try stub.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    /// Open the active config in the user's default editor for `.ghostty`
    /// files (falls back to TextEdit if nothing is registered).
    func openActiveConfig() {
        NSWorkspace.shared.open(fileURL)
    }

    /// Replace the entire `ParsedConfig` — used by undo of bulky profile
    /// mutations where a fine-grained diff isn't worth the complexity.
    private func replaceParsedConfig(_ parsed: ParsedConfig, label: String) {
        undoManager?.setActionName(label)
        mutateFile { file in
            file.parsed = parsed
        }
        schedulePersist()
    }
}

enum ProfileMoveDirection {
    case up
    case down
}

private extension ConfigEntry {
    var isInclude: Bool {
        if case .include = self { return true }
        return false
    }
}

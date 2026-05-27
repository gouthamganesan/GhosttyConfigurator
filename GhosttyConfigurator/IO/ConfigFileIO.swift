import Foundation
import os

/// Actor that reads and writes the Ghostty config file. All filesystem work
/// lives off the main actor; SwiftUI/`ConfigStore` only awaits results.
///
/// Writes are atomic via `FileManager.replaceItemAt` — the existing file is
/// only swapped in once the new content is fully on disk. Crashes mid-write
/// leave the original intact.
actor ConfigFileIO {
    let fileURL: URL

    /// SHA256 of the bytes most recently written by us. Used by callers to
    /// distinguish "FSEvents fired because we just wrote" from "user edited
    /// the file externally."
    private(set) var lastSavedHash: Int = 0

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    // MARK: - Read

    /// Read the file from disk and parse it. Missing file → empty config
    /// (not an error — first-run users have nothing yet).
    func read() async throws -> ConfigFile {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            Logger.parser.info("config file not found at \(self.fileURL.path, privacy: .public); using empty")
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        let source = String(decoding: data, as: UTF8.self)
        lastSavedHash = source.hashValue
        return ConfigFile(parsed: ConfigParser.parse(source))
    }

    // MARK: - Write

    /// Serialize and atomically write the file. Creates parent directories if
    /// they don't exist yet (Application Support folder on a fresh install).
    /// Updates `lastSavedHash` on success.
    func write(_ file: ConfigFile) async throws {
        let source = file.serialized()
        let data = Data(source.utf8)

        let fm = FileManager.default
        let parent = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        // Write to a sibling temp file, then atomically swap in.
        let tempURL = parent.appendingPathComponent(
            ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        try data.write(to: tempURL, options: .atomic)

        if fm.fileExists(atPath: fileURL.path) {
            _ = try fm.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try fm.moveItem(at: tempURL, to: fileURL)
        }

        lastSavedHash = source.hashValue
        Logger.parser.info("wrote \(data.count) bytes to \(self.fileURL.path, privacy: .public)")
    }

    // MARK: - Hash check (for external-edit detection)

    /// Re-hash the on-disk file without re-parsing. Cheap pre-check before
    /// committing to a full reload after FSEvents fires.
    func currentDiskHash() -> Int? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let source = String(decoding: data, as: UTF8.self)
        return source.hashValue
    }

    /// True if the disk content's hash differs from our last write.
    func hasExternalChanges() -> Bool {
        guard let hash = currentDiskHash() else { return false }
        return hash != lastSavedHash
    }
}

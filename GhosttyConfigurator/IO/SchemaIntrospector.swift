import Foundation
import os

/// Loads the Ghostty schema by shelling out to
/// `ghostty +show-config --default --docs` and parsing the comment-block-
/// then-`key = default` text format Ghostty emits. Cached on disk under
/// Application Support, keyed by Ghostty version so upgrades invalidate.
actor SchemaIntrospector {
    static let shared = SchemaIntrospector()

    private var inMemory: Schema?

    /// Get the schema (cached → disk → fresh introspect, in that order).
    func schema() async -> Schema {
        if let inMemory { return inMemory }

        let version = currentGhosttyVersion()

        // Disk cache.
        if let cached = readCache(), cached.ghosttyVersion == version {
            inMemory = cached
            return cached
        }

        // Fresh introspect.
        let fresh = await introspect(version: version)
        inMemory = fresh
        writeCache(fresh)
        return fresh
    }

    // MARK: - Introspect

    private func introspect(version: String) async -> Schema {
        guard let cli = ConfigPaths.ghosttyCLIURL() else {
            Logger.parser.warning("Ghostty CLI not found; returning empty schema")
            return Schema(ghosttyVersion: version, entries: [:])
        }

        let output: String
        do {
            output = try await runProcess(cli.path, args: ["+show-config", "--default", "--docs"])
        } catch {
            Logger.parser.error("schema introspect failed: \(String(describing: error), privacy: .public)")
            return Schema(ghosttyVersion: version, entries: [:])
        }

        let entries = parse(output)
        Logger.parser.info("introspected \(entries.count) schema entries (ghostty \(version, privacy: .public))")
        return Schema(ghosttyVersion: version, entries: entries)
    }

    /// Parse the text output. Format:
    ///
    ///     # comment line 1
    ///     # comment line 2
    ///     #
    ///     # more
    ///     key = default
    ///
    /// Returns a dictionary keyed by `key`.
    nonisolated func parse(_ source: String) -> [String: SchemaEntry] {
        var entries: [String: SchemaEntry] = [:]
        var docBuffer: [String] = []

        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // Blank lines BETWEEN entries reset the buffer. Blank `#` lines
                // (handled below) preserve it as a paragraph break.
                if !docBuffer.isEmpty && docBuffer.last != "" {
                    docBuffer.append("")
                }
                continue
            }

            if trimmed.hasPrefix("#") {
                // Strip `#` and one optional space; preserve the rest verbatim.
                var stripped = String(trimmed.dropFirst())
                if stripped.first == " " { stripped.removeFirst() }
                docBuffer.append(stripped)
                continue
            }

            // Otherwise this is a `key = value` line.
            guard let eq = line.firstIndex(of: "=") else {
                docBuffer.removeAll()
                continue
            }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            let docs = renderDocs(docBuffer)

            entries[key] = SchemaEntry(key: key, defaultValue: value, docs: docs)
            docBuffer.removeAll()
        }

        return entries
    }

    private nonisolated func renderDocs(_ lines: [String]) -> String {
        // Collapse runs of blank-string entries into single paragraph breaks.
        var out: [String] = []
        var currentPara: [String] = []
        for line in lines {
            if line.isEmpty {
                if !currentPara.isEmpty {
                    out.append(currentPara.joined(separator: " "))
                    currentPara.removeAll()
                }
            } else {
                currentPara.append(line)
            }
        }
        if !currentPara.isEmpty {
            out.append(currentPara.joined(separator: " "))
        }
        return out.joined(separator: "\n\n")
    }

    // MARK: - Version detection

    private nonisolated func currentGhosttyVersion() -> String {
        guard let cli = ConfigPaths.ghosttyCLIURL() else { return "" }
        let task = Process()
        task.executableURL = cli
        task.arguments = ["--version"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            // First line is typically "Ghostty 1.3.1". Take the version token.
            if let first = output.split(separator: "\n").first {
                let parts = first.split(separator: " ")
                if parts.count >= 2 { return String(parts[1]) }
                return String(first)
            }
            return output
        } catch {
            return ""
        }
    }

    // MARK: - Process runner

    private nonisolated func runProcess(_ path: String, args: [String]) async throws -> String {
        try await Task.detached { () throws -> String in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = args
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self)
        }.value
    }

    // MARK: - Cache

    private nonisolated func cacheURL() -> URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true) else { return nil }
        let appDir = dir.appendingPathComponent("com.gouthamj.ghostty-configurator", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("schema-cache.json")
    }

    private nonisolated func readCache() -> Schema? {
        guard let url = cacheURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Schema.self, from: data)
    }

    private nonisolated func writeCache(_ schema: Schema) {
        guard let url = cacheURL() else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(schema) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

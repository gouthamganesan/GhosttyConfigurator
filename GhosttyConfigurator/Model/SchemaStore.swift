import Foundation
import Observation
import os

/// Globally observable schema store. ConfigStore reads from this for defaults
/// and DocTooltip pulls doc text from here.
///
/// Loading runs in a detached background task (kicked off by the root view's
/// `.task`) and writes a cached JSON file to Application Support so subsequent
/// launches are instant.
@Observable
@MainActor
final class SchemaStore {
    static let shared = SchemaStore()

    private(set) var schema: Schema = .empty
    private(set) var isLoaded: Bool = false
    private(set) var lastError: String?

    func loadIfNeeded() async {
        guard !isLoaded else { return }

        // 1. Always start with the bundled schema so DocTooltip works immediately
        // — even before any runtime CLI introspection completes.
        if let bundled = Self.loadBundledSchema() {
            schema = bundled
            isLoaded = true
            Logger.parser.info("SchemaStore: loaded \(bundled.entries.count) entries from bundle")
        }

        // 2. Best-effort: try the user's cache (if it exists from a prior run).
        if let cached = Self.readCache(), cached.entries.count >= schema.entries.count {
            schema = cached
            isLoaded = true
            Logger.parser.info("SchemaStore: refreshed from disk cache (\(cached.entries.count) entries)")
        }

        // 3. Best-effort: try to introspect the running Ghostty in case the
        // user has a newer build than what we bundled. Failures are silent —
        // bundled schema is the floor.
        do {
            let version = await Self.detectGhosttyVersion()
            guard !version.isEmpty else { return }
            let output = try await Self.runIntrospection()
            let entries = Self.parse(output)
            let fresh = Schema(ghosttyVersion: version, entries: entries)
            if fresh.entries.count >= schema.entries.count {
                schema = fresh
                Self.writeCache(fresh)
                Logger.parser
                    .info(
                        "SchemaStore: introspected \(fresh.entries.count) entries (ghostty \(version, privacy: .public))"
                    )
            }
        } catch {
            let message = String(describing: error)
            lastError = message
            Logger.parser.error("SchemaStore: introspection failed (using bundled) — \(message, privacy: .public)")
        }
    }

    /// Load the `BundledSchema.json` shipped inside the app bundle. The build
    /// generates this from `ghostty +show-config --default --docs` at the
    /// Ghostty version that was current at build time.
    private static func loadBundledSchema() -> Schema? {
        guard let url = Bundle.main.url(forResource: "BundledSchema", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Schema.self, from: data)
    }

    func entry(for key: String) -> SchemaEntry? {
        schema.entry(for: key)
    }

    func defaultValue(for key: String, fallback: String) -> String {
        schema.entry(for: key)?.defaultValue ?? fallback
    }

    // MARK: - Introspection (static so it's nonisolated by default)

    enum IntrospectionError: Error, CustomStringConvertible {
        case ghosttyNotFound
        case processFailed(Int32, String)

        var description: String {
            switch self {
            case .ghosttyNotFound: "Ghostty isn't installed at /Applications/Ghostty.app."
            case let .processFailed(code, stderr): "ghostty exited \(code): \(stderr)"
            }
        }
    }

    private static func runIntrospection() async throws -> String {
        try await Task.detached(priority: .userInitiated) { () throws -> String in
            let cliPath = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
            guard FileManager.default.fileExists(atPath: cliPath) else {
                throw IntrospectionError.ghosttyNotFound
            }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = ["+show-config", "--default", "--docs"]
            let out = Pipe()
            let err = Pipe()
            task.standardOutput = out
            task.standardError = err
            try task.run()
            task.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            if task.terminationStatus != 0 {
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                throw IntrospectionError.processFailed(
                    task.terminationStatus,
                    String(decoding: errData, as: UTF8.self)
                )
            }
            return String(decoding: data, as: UTF8.self)
        }.value
    }

    private static func detectGhosttyVersion() async -> String {
        await Task.detached(priority: .userInitiated) { () -> String in
            let cliPath = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
            guard FileManager.default.fileExists(atPath: cliPath) else { return "" }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = ["--version"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                if let first = output.split(separator: "\n").first {
                    let parts = first.split(separator: " ")
                    if parts.count >= 2 { return String(parts[1]) }
                    return String(first)
                }
                return ""
            } catch {
                return ""
            }
        }.value
    }

    // MARK: - Parsing (kept here so SchemaIntrospector can be removed)

    /// Parse the text output of `ghostty +show-config --default --docs`.
    /// Format: comment block (`# ...` lines) then `key = default` line.
    nonisolated static func parse(_ source: String) -> [String: SchemaEntry] {
        var entries: [String: SchemaEntry] = [:]
        var docBuffer: [String] = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !docBuffer.isEmpty, docBuffer.last != "" {
                    docBuffer.append("")
                }
                continue
            }

            if trimmed.hasPrefix("#") {
                var stripped = String(trimmed.dropFirst())
                if stripped.first == " " { stripped.removeFirst() }
                docBuffer.append(stripped)
                continue
            }

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

    private nonisolated static func renderDocs(_ lines: [String]) -> String {
        var out: [String] = []
        var paragraph: [String] = []
        for line in lines {
            if line.isEmpty {
                if !paragraph.isEmpty {
                    out.append(paragraph.joined(separator: " "))
                    paragraph.removeAll()
                }
            } else {
                paragraph.append(line)
            }
        }
        if !paragraph.isEmpty {
            out.append(paragraph.joined(separator: " "))
        }
        return out.joined(separator: "\n\n")
    }

    // MARK: - Cache

    private static func cacheURL() -> URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let appDir = dir.appendingPathComponent("com.gouthamj.ghostty-configurator", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("schema-cache.json")
    }

    private static func readCache() -> Schema? {
        guard let url = cacheURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Schema.self, from: data)
    }

    private static func writeCache(_ schema: Schema) {
        guard let url = cacheURL() else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(schema) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

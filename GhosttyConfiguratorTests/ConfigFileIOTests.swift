@testable import GhosttyConfigurator
import XCTest

/// Integration tests that exercise `ConfigFileIO` against the real filesystem
/// (a temp directory copy of Goutham's actual config).
final class ConfigFileIOTests: XCTestCase {
    private var tempDir: URL!
    private var configURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let fm = FileManager.default
        tempDir = fm.temporaryDirectory.appendingPathComponent("ghostty-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configURL = tempDir.appendingPathComponent("config.ghostty")

        let source = try Fixtures.string("real-goutham")
        try source.write(to: configURL, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Round-trip via the actor

    func testReadWriteRoundTripPreservesEveryByte() async throws {
        let io = ConfigFileIO(fileURL: configURL)
        let original = try await io.read()
        try await io.write(original)

        let onDisk = try String(contentsOf: configURL, encoding: .utf8)
        let fixture = try Fixtures.string("real-goutham")
        XCTAssertEqual(onDisk, fixture, "read → write must be byte-identical when no mutations applied")
    }

    func testEditPreservesUnrelatedComments() async throws {
        let io = ConfigFileIO(fileURL: configURL)
        var file = try await io.read()
        file.setScalar("cursor-style", value: "block")
        try await io.write(file)

        let onDisk = try String(contentsOf: configURL, encoding: .utf8)
        let originalLines = try (Fixtures.string("real-goutham"))
            .split(separator: "\n", omittingEmptySubsequences: false)
        let outputLines = onDisk
            .split(separator: "\n", omittingEmptySubsequences: false)

        XCTAssertEqual(originalLines.count, outputLines.count, "no lines added or removed")
        for (orig, out) in zip(originalLines, outputLines) {
            if orig.contains("cursor-style") { continue }
            XCTAssertEqual(String(orig), String(out), "non-edited line drifted")
        }

        // Re-read goes through the parser again; the edit must still be there.
        let reloaded = try await io.read()
        XCTAssertEqual(reloaded.scalarValue(for: "cursor-style"), "block")
    }

    func testHasExternalChangesDetectsEditsWeDidntMake() async throws {
        let io = ConfigFileIO(fileURL: configURL)
        _ = try await io.read()
        let mineBefore = await io.hasExternalChanges()
        XCTAssertFalse(mineBefore, "fresh read should not look like an external edit")

        // Simulate someone else (vim, sync) editing the file.
        try "font-size = 99\n".write(to: configURL, atomically: true, encoding: .utf8)
        let external = await io.hasExternalChanges()
        XCTAssertTrue(external, "external edit must be detected")
    }

    func testWriteCreatesFileWhenAbsent() async throws {
        let fresh = tempDir.appendingPathComponent("nested/dir/config.ghostty")
        let io = ConfigFileIO(fileURL: fresh)
        var file = ConfigFile.empty
        file.setScalar("theme", value: "Tokyo Night")
        try await io.write(file)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        let contents = try String(contentsOf: fresh, encoding: .utf8)
        XCTAssertTrue(contents.contains("theme = Tokyo Night"))
    }
}

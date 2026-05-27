import XCTest
@testable import GhosttyConfigurator

final class ThemeImportTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghostty-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        try super.tearDownWithError()
    }

    func testImportsITermColorsIntoGhosttyTheme() throws {
        let bundle = Bundle(for: type(of: self))
        guard let fixtureURL = bundle.url(forResource: "sample", withExtension: "itermcolors")
            ?? bundle.url(forResource: "sample", withExtension: "itermcolors", subdirectory: "Fixtures") else {
            return XCTFail("sample.itermcolors not in test bundle")
        }

        let written = try ThemeImport.importTheme(from: fixtureURL, intoUserThemesDir: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path))

        let body = try String(contentsOf: written, encoding: .utf8)
        // Palette entries we set.
        XCTAssertTrue(body.contains("palette = 0=#000000"))
        XCTAssertTrue(body.contains("palette = 1=#FF0000"))
        // Background/foreground mappings.
        XCTAssertTrue(body.contains("background = #1E1E2E"))
        XCTAssertTrue(body.contains("foreground = #CDD6F4"))
        XCTAssertTrue(body.contains("cursor-color = #F5E0DC"))

        // File should parse cleanly through our own theme pipeline.
        let parsed = ConfigParser.parse(body)
        let file = ConfigFile(parsed: parsed)
        XCTAssertEqual(file.scalarValue(for: "background"), "#1E1E2E")
        XCTAssertEqual(file.scalarValue(for: "cursor-color"), "#F5E0DC")
        XCTAssertEqual(file.listValues(for: "palette").count, 2,
                       "Expected the two palette entries we provided in the fixture")
    }

    func testUnsupportedFormatThrows() {
        let url = tempDir.appendingPathComponent("foo.toml")
        try? "[colors]".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ThemeImport.importTheme(from: url, intoUserThemesDir: tempDir))
    }
}

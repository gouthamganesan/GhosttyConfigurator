@testable import GhosttyConfigurator
import XCTest

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
            ?? bundle.url(forResource: "sample", withExtension: "itermcolors", subdirectory: "Fixtures")
        else {
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
        XCTAssertEqual(
            file.listValues(for: "palette").count,
            2,
            "Expected the two palette entries we provided in the fixture"
        )
    }

    func testUnsupportedFormatThrows() {
        // Windows Terminal .json is detected but its converter is still a stub.
        let url = tempDir.appendingPathComponent("foo.json")
        try? "{}".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ThemeImport.importTheme(from: url, intoUserThemesDir: tempDir))
    }

    // MARK: - Alacritty TOML

    private func writeToml(_ body: String, name: String = "theme.toml") throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testImportsAlacrittyTomlIntoGhosttyTheme() throws {
        let toml = """
        # Sample Alacritty theme
        [colors.primary]
        background = "#1d1f21"
        foreground = "0xc5c8c6"  # inline comment, 0x form

        [colors.cursor]
        text = "#1d1f21"
        cursor = "#c5c8c6"

        [colors.selection]
        text = "#eaeaea"
        background = "#404040"

        [colors.normal]
        black = "#1d1f21"
        red = "#cc6666"
        green = "#b5bd68"
        yellow = "#f0c674"
        blue = "#81a2be"
        magenta = "#b294bb"
        cyan = "#8abeb7"
        white = "#c5c8c6"

        [colors.bright]
        black = "#666666"
        red = "#d54e53"
        green = "#b9ca4a"
        yellow = "#e7c547"
        blue = "#7aa6da"
        magenta = "#c397d8"
        cyan = "#70c0b1"
        white = "#eaeaea"
        """
        let url = try writeToml(toml)
        let written = try ThemeImport.importTheme(from: url, intoUserThemesDir: tempDir)

        let body = try String(contentsOf: written, encoding: .utf8)
        // Primary / cursor / selection mappings (uppercased hex).
        XCTAssertTrue(body.contains("background = #1D1F21"))
        XCTAssertTrue(body.contains("foreground = #C5C8C6"), "0x form should normalize")
        XCTAssertTrue(body.contains("cursor-color = #C5C8C6"))
        XCTAssertTrue(body.contains("cursor-text = #1D1F21"))
        XCTAssertTrue(body.contains("selection-background = #404040"))
        XCTAssertTrue(body.contains("selection-foreground = #EAEAEA"))
        // Palette: normal 0..7, bright 8..15.
        XCTAssertTrue(body.contains("palette = 0=#1D1F21"))
        XCTAssertTrue(body.contains("palette = 1=#CC6666"))
        XCTAssertTrue(body.contains("palette = 8=#666666"))
        XCTAssertTrue(body.contains("palette = 15=#EAEAEA"))

        // Round-trips through our own pipeline.
        let file = ConfigFile(parsed: ConfigParser.parse(body))
        XCTAssertEqual(file.scalarValue(for: "background"), "#1D1F21")
        XCTAssertEqual(file.listValues(for: "palette").count, 16)
    }

    func testAlacrittyWithNoColorsThrows() throws {
        let url = try writeToml("[general]\nlive_config_reload = true\n")
        XCTAssertThrowsError(try ThemeImport.importTheme(from: url, intoUserThemesDir: tempDir)) { error in
            guard case ThemeImport.ImportError.parseFailed = error else {
                return XCTFail("expected parseFailed, got \(error)")
            }
        }
    }
}

import XCTest
@testable import GhosttyConfigurator

final class ConfigFileTests: XCTestCase {
    // MARK: - Reading

    func testScalarValueReturnsLastWin() {
        // For scalar keys, "later overrides earlier" — Ghostty's semantics.
        let source = "font-size = 13\nfont-size = 14\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        XCTAssertEqual(file.scalarValue(for: "font-size"), "14")
    }

    func testListValuesPreserveOrder() throws {
        let source = try Fixtures.string("list-typed")
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        XCTAssertEqual(
            file.listValues(for: "font-family"),
            ["JetBrains Mono", "Apple Color Emoji", "Symbols Nerd Font"]
        )
    }

    // MARK: - Mutation preserves surrounding entries

    func testSetScalarMutatesInPlacePreservingComments() throws {
        let source = try Fixtures.string("real-goutham")
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setScalar("font-size", value: "16")
        let output = file.serialized()

        // The font-size line was changed.
        XCTAssertTrue(output.contains("font-size = 16"))
        XCTAssertFalse(output.contains("font-size = 14"))
        // Other lines (a comment-less but still ordered file) are intact.
        XCTAssertTrue(output.contains("font-family = Geist Mono"))
        XCTAssertTrue(output.contains("theme = light:\"Flexoki Light\",dark:\"Flexoki Dark\""))
        XCTAssertTrue(output.contains("window-title-font-family = Giest Mono"))
    }

    func testSetScalarAppendsWhenAbsent() {
        var file = ConfigFile(parsed: ConfigParser.parse("font-size = 14\n"))
        file.setScalar("background-opacity", value: "0.95")
        let output = file.serialized()
        XCTAssertTrue(output.contains("background-opacity = 0.95"))
        XCTAssertTrue(output.contains("font-size = 14"))
    }

    func testSetListReplacesAllMatching() throws {
        let source = try Fixtures.string("list-typed")
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setList("font-family", values: ["Fira Code", "Apple Color Emoji"])
        let result = file.listValues(for: "font-family")
        XCTAssertEqual(result, ["Fira Code", "Apple Color Emoji"])

        let output = file.serialized()
        // The keybind block is untouched.
        XCTAssertTrue(output.contains("keybind = ctrl+z=close_surface"))
        XCTAssertTrue(output.contains("# Multiple fonts for fallback order."))
    }

    func testAppendListAddsAfterLastMatchingEntry() throws {
        let source = try Fixtures.string("list-typed")
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.appendList("font-family", value: "Fira Code")
        XCTAssertEqual(
            file.listValues(for: "font-family"),
            ["JetBrains Mono", "Apple Color Emoji", "Symbols Nerd Font", "Fira Code"]
        )
    }

    func testResetEmitsEmptyValue() {
        var file = ConfigFile(parsed: ConfigParser.parse("font-size = 14\n"))
        file.reset("font-size")
        XCTAssertTrue(file.serialized().contains("font-size ="))
    }

    func testDeleteRemovesLines() {
        var file = ConfigFile(parsed: ConfigParser.parse("font-size = 14\ntheme = X\n"))
        XCTAssertTrue(file.delete("font-size"))
        XCTAssertFalse(file.serialized().contains("font-size"))
        XCTAssertTrue(file.serialized().contains("theme = X"))
    }

    // MARK: - End-to-end: real config edited and re-serialized

    /// Regression test against Goutham's actual config — the most realistic
    /// corpus we have. Every comment / ordering / quirk (including the
    /// `Giest Mono` typo) survives a round-trip + one mutation.
    func testRealConfigSurvivesEditPlusRoundtrip() throws {
        let source = try Fixtures.string("real-goutham")
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setScalar("cursor-style", value: "block")
        let output = file.serialized()

        // The edited key changed.
        XCTAssertTrue(output.contains("cursor-style = block"))
        XCTAssertFalse(output.contains("cursor-style = bar"))

        // Every other line is byte-identical to the source.
        let originalLines = source.split(separator: "\n", omittingEmptySubsequences: false)
        let outputLines = output.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(originalLines.count, outputLines.count, "line count must not change")
        for (orig, out) in zip(originalLines, outputLines) {
            if orig.contains("cursor-style") { continue }
            XCTAssertEqual(String(orig), String(out), "non-edited line drifted")
        }
    }
}

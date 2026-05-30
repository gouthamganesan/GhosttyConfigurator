import XCTest
@testable import GhosttyConfigurator

/// Round-trip coverage for the Cursor pane enum migrations (B1):
/// - `cursor-style-blink` Bool → tri-state enum (default / always / never)
/// - `cursor-text` 4-state enum (default / cell-bg / cell-fg / custom)
final class CursorEnumsTests: XCTestCase {

    // MARK: - cursor-style-blink

    func testBlinkRawValues() {
        XCTAssertEqual(CursorStyleBlink(rawValue: "true"), .alwaysBlink)
        XCTAssertEqual(CursorStyleBlink(rawValue: "false"), .neverBlink)
        XCTAssertEqual(CursorStyleBlink(rawValue: "default"), .default)
    }

    func testBlinkSerialization() {
        XCTAssertEqual(CursorStyleBlink.alwaysBlink.rawValue, "true")
        XCTAssertEqual(CursorStyleBlink.neverBlink.rawValue, "false")
        // .default's raw is "default" but isn't expected to be written —
        // ConfigStore deletes the key for .default. Tested via integration.
    }

    func testBlinkReadFromConfig() {
        let trueSrc = ConfigFile(parsed: ConfigParser.parse("cursor-style-blink = true\n"))
        XCTAssertEqual(CursorStyleBlink(rawValue: trueSrc.scalarValue(for: "cursor-style-blink") ?? ""), .alwaysBlink)

        let falseSrc = ConfigFile(parsed: ConfigParser.parse("cursor-style-blink = false\n"))
        XCTAssertEqual(CursorStyleBlink(rawValue: falseSrc.scalarValue(for: "cursor-style-blink") ?? ""), .neverBlink)
    }

    // MARK: - cursor-text mode derivation

    func testCursorTextModeDefaultWhenAbsent() {
        let file = ConfigFile(parsed: ConfigParser.parse(""))
        XCTAssertEqual(file.cursorTextMode(), .default)
    }

    func testCursorTextModeCellBackground() {
        let file = ConfigFile(parsed: ConfigParser.parse("cursor-text = cell-background\n"))
        XCTAssertEqual(file.cursorTextMode(), .cellBackground)
    }

    func testCursorTextModeCellForeground() {
        let file = ConfigFile(parsed: ConfigParser.parse("cursor-text = cell-foreground\n"))
        XCTAssertEqual(file.cursorTextMode(), .cellForeground)
    }

    func testCursorTextModeCustomHex() {
        let file = ConfigFile(parsed: ConfigParser.parse("cursor-text = #aabbcc\n"))
        XCTAssertEqual(file.cursorTextMode(), .custom)
    }

    func testCursorTextModeFallsBackOnGarbage() {
        let file = ConfigFile(parsed: ConfigParser.parse("cursor-text = banana\n"))
        XCTAssertEqual(file.cursorTextMode(), .default)
    }

    func testCursorTextModeLastWriteWins() {
        let source = "cursor-text = cell-background\ncursor-text = #112233\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        XCTAssertEqual(file.cursorTextMode(), .custom)
    }

    // MARK: - All enum raw values cover the documented Ghostty values

    func testCursorTextModeRawValuesMatchSchema() {
        XCTAssertEqual(CursorTextMode.cellBackground.rawValue, "cell-background")
        XCTAssertEqual(CursorTextMode.cellForeground.rawValue, "cell-foreground")
    }
}

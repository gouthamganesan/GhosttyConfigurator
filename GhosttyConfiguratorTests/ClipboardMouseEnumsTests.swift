@testable import GhosttyConfigurator
import XCTest

/// Round-trip coverage for the Clipboard & Mouse pane additions (B4):
/// - `right-click-action` 5-state enum
/// - `scrollbar` 2-state enum
/// - `scroll-to-bottom` comma-flag list (keystroke / output)
final class ClipboardMouseEnumsTests: XCTestCase {
    // MARK: - right-click-action

    func testRightClickActionAllRawValues() {
        XCTAssertEqual(RightClickAction(rawValue: "context-menu"), .contextMenu)
        XCTAssertEqual(RightClickAction(rawValue: "paste"), .paste)
        XCTAssertEqual(RightClickAction(rawValue: "copy"), .copy)
        XCTAssertEqual(RightClickAction(rawValue: "copy-or-paste"), .copyOrPaste)
        XCTAssertEqual(RightClickAction(rawValue: "ignore"), .ignore)
    }

    func testRightClickActionReadFromConfig() {
        let source = "right-click-action = copy-or-paste\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(RightClickAction.self, for: "right-click-action", default: .contextMenu)
        XCTAssertEqual(value, .copyOrPaste)
    }

    // MARK: - scrollbar

    func testScrollbarRawValues() {
        XCTAssertEqual(Scrollbar(rawValue: "system"), .system)
        XCTAssertEqual(Scrollbar(rawValue: "never"), .never)
    }

    func testScrollbarFallback() {
        let file = ConfigFile(parsed: ConfigParser.parse("scrollbar = nonsense\n"))
        let value = file.enumValue(Scrollbar.self, for: "scrollbar", default: .system)
        XCTAssertEqual(value, .system)
    }

    // MARK: - scroll-to-bottom comma-flag list

    func testScrollToBottomReadsKeystrokeOnly() {
        // Default Ghostty value: "keystroke,no-output"
        let source = "scroll-to-bottom = keystroke,no-output\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let flags = file.commaFlags(for: "scroll-to-bottom")
        XCTAssertTrue(flags.contains("keystroke"))
        XCTAssertTrue(flags.contains("no-output"))
        XCTAssertFalse(flags.contains("output"))
    }

    func testScrollToBottomToggleOutputOn() {
        var file = ConfigFile(parsed: ConfigParser.parse("scroll-to-bottom = keystroke,no-output\n"))
        file.setCommaFlag("scroll-to-bottom", flag: "output", enabled: true)
        let flags = file.commaFlags(for: "scroll-to-bottom")
        XCTAssertTrue(flags.contains("keystroke"))
        XCTAssertTrue(flags.contains("output"))
        XCTAssertFalse(flags.contains("no-output"), "Positive form should replace negative")
    }

    func testScrollToBottomDisableKeystroke() {
        var file = ConfigFile(parsed: ConfigParser.parse("scroll-to-bottom = keystroke\n"))
        file.setCommaFlag("scroll-to-bottom", flag: "keystroke", enabled: false)
        let flags = file.commaFlags(for: "scroll-to-bottom")
        XCTAssertTrue(flags.contains("no-keystroke"))
        XCTAssertFalse(flags.contains("keystroke"))
    }

    // MARK: - scrollback-limit bytes ↔ MB

    func testScrollbackLimitBytesReadAsInt() {
        let file = ConfigFile(parsed: ConfigParser.parse("scrollback-limit = 50000000\n"))
        XCTAssertEqual(file.int(for: "scrollback-limit", default: 0), 50_000_000)
    }
}

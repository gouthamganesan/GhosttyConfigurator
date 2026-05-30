@testable import GhosttyConfigurator
import XCTest

/// Round-trip coverage for the Keyboard pane B5 work:
/// - `macos-option-as-alt` 5-state enum (`.default` represents "key absent")
final class KeyboardEnumsTests: XCTestCase {
    // MARK: - Raw-value round-trip

    func testMacosOptionAsAltAllRawValues() {
        XCTAssertEqual(MacosOptionAsAlt(rawValue: "default"), .default)
        XCTAssertEqual(MacosOptionAsAlt(rawValue: "false"), .off)
        XCTAssertEqual(MacosOptionAsAlt(rawValue: "true"), .both)
        XCTAssertEqual(MacosOptionAsAlt(rawValue: "left"), .left)
        XCTAssertEqual(MacosOptionAsAlt(rawValue: "right"), .right)
    }

    func testMacosOptionAsAltSerialization() {
        XCTAssertEqual(MacosOptionAsAlt.off.rawValue, "false")
        XCTAssertEqual(MacosOptionAsAlt.both.rawValue, "true")
        XCTAssertEqual(MacosOptionAsAlt.left.rawValue, "left")
        XCTAssertEqual(MacosOptionAsAlt.right.rawValue, "right")
    }

    // MARK: - Config-file integration

    func testOptionAsAltReadFromConfig() {
        let source = "macos-option-as-alt = left\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosOptionAsAlt.self, for: "macos-option-as-alt", default: .default)
        XCTAssertEqual(value, .left)
    }

    func testOptionAsAltAbsentFallsBackToDefault() {
        // No entry at all → Auto / `.default` (we treat absent and unparseable
        // the same way in the store, so the picker shows "Auto").
        let file = ConfigFile()
        let value = file.enumValue(MacosOptionAsAlt.self, for: "macos-option-as-alt", default: .default)
        XCTAssertEqual(value, .default)
    }

    func testOptionAsAltGarbageFallsBackToDefault() {
        let source = "macos-option-as-alt = banana\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosOptionAsAlt.self, for: "macos-option-as-alt", default: .default)
        XCTAssertEqual(value, .default)
    }

    func testOptionAsAltExplicitOffReadsAsOff() {
        let source = "macos-option-as-alt = false\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosOptionAsAlt.self, for: "macos-option-as-alt", default: .default)
        XCTAssertEqual(value, .off)
        XCTAssertNotEqual(
            value,
            .default,
            "`false` must be distinguishable from absent so the modification dot fires."
        )
    }

    func testOptionAsAltBothReadsAsBoth() {
        let source = "macos-option-as-alt = true\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosOptionAsAlt.self, for: "macos-option-as-alt", default: .default)
        XCTAssertEqual(value, .both)
    }

    // MARK: - macos-shortcuts (tri-state, not Bool)

    func testMacosShortcutsAllRawValues() {
        XCTAssertEqual(MacosShortcuts(rawValue: "ask"), .ask)
        XCTAssertEqual(MacosShortcuts(rawValue: "allow"), .allow)
        XCTAssertEqual(MacosShortcuts(rawValue: "deny"), .deny)
    }

    func testMacosShortcutsReadFromConfig() {
        let source = "macos-shortcuts = allow\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosShortcuts.self, for: "macos-shortcuts", default: .ask)
        XCTAssertEqual(value, .allow)
    }

    func testMacosShortcutsAbsentFallsBackToAsk() {
        let file = ConfigFile()
        let value = file.enumValue(MacosShortcuts.self, for: "macos-shortcuts", default: .ask)
        XCTAssertEqual(value, .ask)
    }
}

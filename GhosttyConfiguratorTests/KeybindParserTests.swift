@testable import GhosttyConfigurator
import XCTest

/// Coverage for the parser bug fixes prompted by Ghostty's defaults having
/// `=` keys in triggers (⌘= and ⌘+ → increase font size).
final class KeybindParserTests: XCTestCase {
    // MARK: - Action-separator split

    func testTriggerWithEqualsKey() {
        // `super+==increase_font_size:1` — the first `=` is the `=` key, the
        // second is the action separator. Naive split-on-first would mangle this.
        let kb = KeybindParser.parse("super+==increase_font_size:1")
        XCTAssertNotNil(kb)
        XCTAssertEqual(kb?.action.verb, "increase_font_size")
        XCTAssertEqual(kb?.action.parameter, "1")
        XCTAssertTrue(kb?.modifiers.contains(.cmd) ?? false)
        XCTAssertEqual(kb?.key, "=")
    }

    func testTriggerWithPlusEqualsKey() {
        // `super++=increase_font_size:1` — ⌘+
        let kb = KeybindParser.parse("super++=increase_font_size:1")
        XCTAssertNotNil(kb)
        XCTAssertEqual(kb?.action.verb, "increase_font_size")
        XCTAssertEqual(kb?.action.parameter, "1")
        XCTAssertTrue(kb?.modifiers.contains(.cmd) ?? false)
    }

    func testSimpleTrigger() {
        let kb = KeybindParser.parse("super+c=copy_to_clipboard:mixed")
        XCTAssertEqual(kb?.action.verb, "copy_to_clipboard")
        XCTAssertEqual(kb?.action.parameter, "mixed")
        XCTAssertEqual(kb?.key, "c")
    }

    func testBareKeyTrigger() {
        // Triggers like `copy=copy_to_clipboard:mixed` (no `+`-separated mods)
        // appear in Ghostty's defaults for the Cmd-less Copy/Paste menu items.
        let kb = KeybindParser.parse("copy=copy_to_clipboard:mixed")
        XCTAssertEqual(kb?.key, "copy")
        XCTAssertTrue(kb?.modifiers.isEmpty ?? false)
        XCTAssertEqual(kb?.action.verb, "copy_to_clipboard")
    }

    func testTextActionParamPreservesEscapes() {
        // The action carries the config-syntax `\\x05`; we don't want to
        // eat one of the backslashes during parse — display layer handles that.
        let kb = KeybindParser.parse(#"super+arrow_right=text:\\x05"#)
        XCTAssertEqual(kb?.action.verb, "text")
        XCTAssertEqual(kb?.action.parameter, #"\\x05"#)
    }

    // MARK: - KeyDisplay

    func testKeyDisplayMapsDigitTokens() {
        XCTAssertEqual(KeyDisplay.label(for: "digit_1"), "1")
        XCTAssertEqual(KeyDisplay.label(for: "digit_9"), "9")
        XCTAssertEqual(KeyDisplay.label(for: "kp_0"), "0")
    }

    func testKeyDisplayMapsArrowTokens() {
        XCTAssertEqual(KeyDisplay.label(for: "arrow_left"), "←")
        XCTAssertEqual(KeyDisplay.label(for: "arrow_right"), "→")
        XCTAssertEqual(KeyDisplay.label(for: "arrow_up"), "↑")
        XCTAssertEqual(KeyDisplay.label(for: "arrow_down"), "↓")
    }

    func testKeyDisplayMapsPagingTokens() {
        XCTAssertEqual(KeyDisplay.label(for: "page_up"), "⇞")
        XCTAssertEqual(KeyDisplay.label(for: "page_down"), "⇟")
        XCTAssertEqual(KeyDisplay.label(for: "home"), "↖")
        XCTAssertEqual(KeyDisplay.label(for: "end"), "↘")
    }

    func testKeyDisplayCapitalisesWordKeys() {
        XCTAssertEqual(KeyDisplay.label(for: "copy"), "Copy")
        XCTAssertEqual(KeyDisplay.label(for: "paste"), "Paste")
        XCTAssertTrue(KeyDisplay.isWord("copy"))
    }

    func testKeyDisplayLeavesFunctionKeysAlone() {
        XCTAssertEqual(KeyDisplay.label(for: "f5"), "f5")
        XCTAssertFalse(KeyDisplay.isWord("f5"))
        XCTAssertFalse(KeyDisplay.isWord("f12"))
    }

    func testKeyDisplayLeavesSingleCharsAlone() {
        XCTAssertEqual(KeyDisplay.label(for: "c"), "c")
        XCTAssertFalse(KeyDisplay.isWord("c"))
    }
}

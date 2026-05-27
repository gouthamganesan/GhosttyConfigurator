import XCTest
@testable import GhosttyConfigurator

final class ConfigParserTests: XCTestCase {
    // MARK: - Round-trip identity (the gate)

    /// Every fixture: parse → serialize → must equal the original input.
    /// This is the single most important invariant the parser must hold.
    func testRoundTripIdentity() throws {
        let fixtures = [
            "empty",
            "comments-only",
            "real-goutham",
            "list-typed",
            "reset-semantics",
            "quoted-values",
            "with-includes",
            "weird-whitespace",
            "no-trailing-newline",
            "crlf"
        ]

        for name in fixtures {
            let source = try Fixtures.string(name)
            let parsed = ConfigParser.parse(source)
            let roundtrip = ConfigParser.serialize(parsed)
            XCTAssertEqual(
                roundtrip,
                source,
                "Round-trip mismatch on fixture '\(name)'"
            )
        }
    }

    // MARK: - Parser semantics

    func testParsesScalarKV() throws {
        let parsed = ConfigParser.parse("font-size = 14\n")
        guard case .kv(let kv) = parsed.entries.first else {
            return XCTFail("expected kv entry")
        }
        XCTAssertEqual(kv.key, "font-size")
        XCTAssertEqual(kv.value, "14")
    }

    func testParsesBlankAndCommentLines() {
        let parsed = ConfigParser.parse("\n# hello\nfont-size = 14\n")
        XCTAssertEqual(parsed.entries.count, 3)
        if case .blank = parsed.entries[0] {} else { XCTFail("expected blank") }
        if case .comment = parsed.entries[1] {} else { XCTFail("expected comment") }
        if case .kv = parsed.entries[2] {} else { XCTFail("expected kv") }
    }

    func testParsesEmptyValueAsResetSemantics() {
        let parsed = ConfigParser.parse("font-family =\n")
        guard case .kv(let kv) = parsed.entries.first else { return XCTFail() }
        XCTAssertEqual(kv.key, "font-family")
        XCTAssertEqual(kv.value, "", "Empty value is preserved (Ghostty's reset-to-default)")
    }

    func testParsesIncludeDirective() {
        let parsed = ConfigParser.parse("config-file = ?optional/path.ghostty\n")
        guard case .include(let inc) = parsed.entries.first else {
            return XCTFail("expected include")
        }
        XCTAssertTrue(inc.isOptional)
        XCTAssertEqual(inc.path, "optional/path.ghostty")
    }

    func testParsesRequiredInclude() {
        let parsed = ConfigParser.parse("config-file = themes/extra.ghostty\n")
        guard case .include(let inc) = parsed.entries.first else { return XCTFail() }
        XCTAssertFalse(inc.isOptional)
        XCTAssertEqual(inc.path, "themes/extra.ghostty")
    }

    func testParsesQuotedIncludePath() {
        // `"?literal"` should be a literal path starting with `?`, not optional.
        let parsed = ConfigParser.parse("config-file = \"?literal\"\n")
        guard case .include(let inc) = parsed.entries.first else { return XCTFail() }
        XCTAssertFalse(inc.isOptional)
        XCTAssertEqual(inc.path, "?literal")
    }

    func testSplitsOnFirstEqualsForKeybinds() {
        // keybind values contain `=` — Ghostty splits on the FIRST `=` only.
        let parsed = ConfigParser.parse("keybind = ctrl+a=copy_to_clipboard\n")
        guard case .kv(let kv) = parsed.entries.first else { return XCTFail() }
        XCTAssertEqual(kv.key, "keybind")
        XCTAssertEqual(kv.value, "ctrl+a=copy_to_clipboard")
    }

    func testMalformedLinePreservedAsComment() {
        // Garbage line with no `=` and no `#` prefix — we preserve verbatim
        // so a save doesn't silently drop user content.
        let source = "not a real config line\n"
        let parsed = ConfigParser.parse(source)
        guard case .comment(let raw) = parsed.entries.first else {
            return XCTFail("expected malformed line preserved as comment-shaped entry")
        }
        XCTAssertEqual(raw, "not a real config line")
        XCTAssertEqual(ConfigParser.serialize(parsed), source)
    }

    // MARK: - Format helpers

    func testFormatKVDoesNotQuoteOrdinaryValues() {
        XCTAssertEqual(ConfigParser.formatKV(key: "font-size", value: "14"), "font-size = 14")
    }

    func testFormatKVQuotesLeadingQuestionMark() {
        XCTAssertEqual(ConfigParser.formatKV(key: "path", value: "?weird"), "path = \"?weird\"")
    }

    func testFormatKVQuotesLeadingHash() {
        XCTAssertEqual(ConfigParser.formatKV(key: "title", value: "#hash"), "title = \"#hash\"")
    }

    func testFormatKVEmitsBareEqualsForReset() {
        XCTAssertEqual(ConfigParser.formatKV(key: "font-family", value: ""), "font-family =")
    }
}

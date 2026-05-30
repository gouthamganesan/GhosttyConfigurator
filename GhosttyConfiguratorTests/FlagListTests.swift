@testable import GhosttyConfigurator
import XCTest

/// Tests for the two "flag list" patterns Ghostty uses:
///   1. `font-feature` — repeated key, each value is `+tag` or `-tag`.
///   2. `shell-integration-features` — single key, value is a comma-separated
///      list with `no-` prefix for explicit-disable.
final class FlagListTests: XCTestCase {
    // MARK: - font-feature

    func testFontFeatureSignReadsExistingTag() {
        let source = """
        font-feature = +liga
        font-feature = -calt
        """
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        XCTAssertEqual(file.fontFeatureSign(for: "liga"), true)
        XCTAssertEqual(file.fontFeatureSign(for: "calt"), false)
        XCTAssertNil(file.fontFeatureSign(for: "ss01"))
    }

    func testSetFontFeatureAddsFirstTime() {
        var file = ConfigFile.empty
        file.setFontFeature("liga", sign: true)
        XCTAssertEqual(file.fontFeatureSign(for: "liga"), true)
        XCTAssertTrue(file.serialized().contains("font-feature = +liga"))
    }

    func testSetFontFeatureMutatesExistingTagWithoutDisturbingOthers() {
        let source = """
        # User config
        font-feature = +liga
        font-feature = -calt
        font-size = 14
        """
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setFontFeature("calt", sign: true)

        XCTAssertEqual(file.fontFeatureSign(for: "calt"), true)
        XCTAssertEqual(file.fontFeatureSign(for: "liga"), true, "ligatures must not be touched")
        XCTAssertTrue(file.serialized().contains("# User config"))
        XCTAssertTrue(file.serialized().contains("font-size = 14"))
    }

    func testSetFontFeatureToNilRemovesEntry() {
        let source = "font-feature = +liga\nfont-feature = -calt\n"
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setFontFeature("liga", sign: nil)
        XCTAssertNil(file.fontFeatureSign(for: "liga"))
        // The other feature is preserved.
        XCTAssertEqual(file.fontFeatureSign(for: "calt"), false)
    }

    // MARK: - shell-integration-features

    func testCommaFlagsReadsExisting() {
        let source = "shell-integration-features = cursor,sudo,no-title\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let flags = file.commaFlags(for: "shell-integration-features")
        XCTAssertEqual(flags, ["cursor", "sudo", "no-title"])
    }

    func testSetCommaFlagEnablesByReplacingNoPrefix() {
        let source = "shell-integration-features = cursor,no-title\n"
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setCommaFlag("shell-integration-features", flag: "title", enabled: true)
        let flags = file.commaFlags(for: "shell-integration-features")
        XCTAssertTrue(flags.contains("title"), "enabling must replace no-title with title")
        XCTAssertFalse(flags.contains("no-title"))
        XCTAssertTrue(flags.contains("cursor"), "unrelated flag preserved")
    }

    func testSetCommaFlagDisablesByWritingNoPrefix() {
        let source = "shell-integration-features = cursor,sudo,title\n"
        var file = ConfigFile(parsed: ConfigParser.parse(source))
        file.setCommaFlag("shell-integration-features", flag: "title", enabled: false)
        let flags = file.commaFlags(for: "shell-integration-features")
        XCTAssertTrue(flags.contains("no-title"))
        XCTAssertFalse(flags.contains("title"))
    }

    func testSetCommaFlagOnEmptyFileCreatesKey() {
        var file = ConfigFile.empty
        file.setCommaFlag("shell-integration-features", flag: "cursor", enabled: true)
        XCTAssertEqual(file.commaFlags(for: "shell-integration-features"), ["cursor"])
        XCTAssertTrue(file.serialized().contains("shell-integration-features = cursor"))
    }
}

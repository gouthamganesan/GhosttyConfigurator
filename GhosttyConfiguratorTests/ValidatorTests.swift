@testable import GhosttyConfigurator
import XCTest

final class ValidatorTests: XCTestCase {
    private let installedFonts: Set<String> = ["JetBrains Mono", "Geist Mono", "Menlo"]
    private let installedThemes: Set<String> = ["Catppuccin Mocha", "Melange Light", "Flexoki Dark"]

    private func file(_ source: String) -> ConfigFile {
        ConfigFile(parsed: ConfigParser.parse(source))
    }

    private func issues(_ source: String) -> [String: ValidationIssue] {
        Validator.issues(
            for: file(source),
            knownThemes: installedThemes,
            knownFontFamilies: installedFonts
        )
    }

    private func issuesWithoutThemeIndex(_ source: String) -> [String: ValidationIssue] {
        Validator.issues(
            for: file(source),
            knownThemes: nil,
            knownFontFamilies: installedFonts
        )
    }

    // MARK: - Theme

    func testUnknownSingleThemeFlagsWarning() {
        let result = issues("theme = Cattpuccin Macchaito")
        XCTAssertEqual(result["theme"]?.severity, .warning)
    }

    func testQuotedKnownThemeIsClean() {
        let result = issues(#"theme = "Catppuccin Mocha""#)
        XCTAssertNil(result["theme"])
    }

    func testPairWithBothKnownIsClean() {
        let result = issues(#"theme = light:"Melange Light",dark:"Flexoki Dark""#)
        XCTAssertNil(result["theme"])
    }

    func testPairWithOneUnknownFlagsWarning() {
        let result = issues(#"theme = light:"Melange Light",dark:"Made Up""#)
        XCTAssertEqual(result["theme"]?.severity, .warning)
        XCTAssertTrue(result["theme"]?.message.contains("Made Up") ?? false)
    }

    func testThemeCheckSkippedWhenIndexNotLoaded() {
        let result = issuesWithoutThemeIndex("theme = AnyOldName")
        XCTAssertNil(result["theme"])
    }

    // MARK: - Font family

    func testUnknownFontFamilyFlagsWarning() {
        let result = issues("font-family = NoSuchFontFamily 9000")
        XCTAssertEqual(result["font-family"]?.severity, .warning)
    }

    func testKnownFontFamilyIsClean() {
        let result = issues("font-family = JetBrains Mono")
        XCTAssertNil(result["font-family"])
    }

    // MARK: - font-size

    func testZeroFontSizeIsError() {
        let result = issues("font-size = 0")
        XCTAssertEqual(result["font-size"]?.severity, .error)
    }

    func testWildlyLargeFontSizeIsWarning() {
        let result = issues("font-size = 200")
        XCTAssertEqual(result["font-size"]?.severity, .warning)
    }

    func testReasonableFontSizeIsClean() {
        let result = issues("font-size = 13")
        XCTAssertNil(result["font-size"])
    }

    // MARK: - background-opacity

    func testZeroOpacityFlagsWarning() {
        let result = issues("background-opacity = 0")
        XCTAssertEqual(result["background-opacity"]?.severity, .warning)
    }

    func testNonZeroOpacityIsClean() {
        let result = issues("background-opacity = 0.3")
        XCTAssertNil(result["background-opacity"])
    }

    // MARK: - command

    func testBareCommandNameIsClean() {
        // "fish" or "zsh" without a path resolves via PATH at runtime.
        let result = issues("command = fish")
        XCTAssertNil(result["command"])
    }

    func testNonexistentAbsoluteCommandFlagsWarning() {
        let result = issues("command = /usr/local/no/such/shell")
        XCTAssertEqual(result["command"]?.severity, .warning)
    }

    func testExistingAbsoluteCommandIsClean() {
        let result = issues("command = /bin/sh")
        XCTAssertNil(result["command"])
    }

    // MARK: - working-directory

    func testNonexistentWorkingDirectoryFlagsWarning() {
        let result = issues("working-directory = /tmp/absolutely-not-a-real-dir-\(UUID().uuidString)")
        XCTAssertEqual(result["working-directory"]?.severity, .warning)
    }

    func testExistingWorkingDirectoryIsClean() {
        let result = issues("working-directory = /tmp")
        XCTAssertNil(result["working-directory"])
    }

    func testInheritSentinelIsClean() {
        let result = issues("working-directory = inherit")
        XCTAssertNil(result["working-directory"])
    }
}

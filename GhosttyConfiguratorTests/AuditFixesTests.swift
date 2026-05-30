@testable import GhosttyConfigurator
import XCTest

/// Coverage for the second audit pass — every Bool-vs-enum / missing-value
/// bug found alongside the macos-shortcuts fix.
final class AuditFixesTests: XCTestCase {
    // MARK: - confirm-close-surface (Bool → tri-state)

    func testConfirmCloseSurfaceAllRawValues() {
        XCTAssertEqual(ConfirmCloseSurface(rawValue: "true"), .whenBusy)
        XCTAssertEqual(ConfirmCloseSurface(rawValue: "false"), .never)
        XCTAssertEqual(ConfirmCloseSurface(rawValue: "always"), .always)
    }

    func testConfirmCloseSurfaceReadFromConfig() {
        let source = "confirm-close-surface = always\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(
            ConfirmCloseSurface.self,
            for: "confirm-close-surface",
            default: .whenBusy
        )
        XCTAssertEqual(value, .always)
    }

    func testConfirmCloseSurfaceAbsentFallsBackToWhenBusy() {
        let file = ConfigFile()
        let value = file.enumValue(
            ConfirmCloseSurface.self,
            for: "confirm-close-surface",
            default: .whenBusy
        )
        XCTAssertEqual(value, .whenBusy)
    }

    // MARK: - shell-integration nushell

    func testShellIntegrationNushell() {
        XCTAssertEqual(ShellIntegration(rawString: "nushell"), .nushell)
        XCTAssertEqual(
            ShellIntegration(rawString: "nu"),
            .nushell,
            "Short alias should round-trip — Ghostty users sometimes write `nu`."
        )
        XCTAssertEqual(ShellIntegration.nushell.configValue, "nushell")
    }

    func testShellIntegrationLegacyValuesStillWork() {
        XCTAssertEqual(ShellIntegration(rawString: "bash"), .bash)
        XCTAssertEqual(ShellIntegration(rawString: "detect"), .detect)
    }

    // MARK: - cursor-style block_hollow

    func testCursorStyleBlockHollow() {
        XCTAssertEqual(CursorStyle(rawValue: "block_hollow"), .blockHollow)
        XCTAssertEqual(CursorStyle.blockHollow.rawValue, "block_hollow")
    }

    func testCursorStyleAllCasesIncludesBlockHollow() {
        XCTAssertTrue(CursorStyle.allCases.contains(.blockHollow))
        XCTAssertEqual(CursorStyle.allCases.count, 4)
    }

    // MARK: - window-decoration legacy true/false aliases

    func testWindowDecorationLegacyTrueReadsAsAuto() {
        XCTAssertEqual(WindowDecoration(rawString: "true"), .auto)
        XCTAssertEqual(
            WindowDecoration(rawString: "TRUE"),
            .auto,
            "Boolean aliases should be case-insensitive — Ghostty accepts both."
        )
    }

    func testWindowDecorationLegacyFalseReadsAsNone() {
        // `.none` is ambiguous with Optional.none; qualify explicitly.
        XCTAssertEqual(WindowDecoration(rawString: "false"), WindowDecoration.none)
    }

    func testWindowDecorationCanonicalValuesStillWork() {
        XCTAssertEqual(WindowDecoration(rawString: "auto"), .auto)
        XCTAssertEqual(WindowDecoration(rawString: "server"), .server)
        XCTAssertEqual(WindowDecoration(rawString: "client"), .client)
        XCTAssertEqual(WindowDecoration(rawString: "none"), WindowDecoration.none)
    }

    func testWindowDecorationGarbageReturnsNil() {
        XCTAssertNil(WindowDecoration(rawString: "banana"))
    }

    // MARK: - background-blur macOS-glass values

    func testBlurLevelGlassRawValues() {
        XCTAssertEqual(BlurLevel(rawString: "macos-glass-regular"), .glassRegular)
        XCTAssertEqual(BlurLevel(rawString: "macos-glass-clear"), .glassClear)
    }

    func testBlurLevelGlassRoundTrip() {
        XCTAssertEqual(BlurLevel.glassRegular.configValue, "macos-glass-regular")
        XCTAssertEqual(BlurLevel.glassClear.configValue, "macos-glass-clear")
    }

    func testBlurLevelNumericBucketsStillWork() {
        XCTAssertEqual(BlurLevel(rawString: "0"), .off)
        XCTAssertEqual(BlurLevel(rawString: "10"), .subtle)
        XCTAssertEqual(BlurLevel(rawString: "20"), .medium)
        XCTAssertEqual(BlurLevel(rawString: "40"), .strong)
        XCTAssertEqual(BlurLevel(rawString: "true"), .medium)
        XCTAssertEqual(BlurLevel(rawString: "false"), .off)
    }
}

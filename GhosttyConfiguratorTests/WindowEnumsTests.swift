import XCTest
@testable import GhosttyConfigurator

/// Round-trip coverage for the Window pane enum migrations (A2):
/// - `macos-non-native-fullscreen` migrated from Bool to a 4-state enum
/// - new enums for proxy-icon, padding-color, new-tab-position, resize-overlay
final class WindowEnumsTests: XCTestCase {

    // MARK: - macos-non-native-fullscreen

    func testNonNativeFullscreenAllRawValues() {
        // Every documented Ghostty value must round-trip via RawRepresentable.
        XCTAssertEqual(MacosNonNativeFullscreen(rawValue: "false"), .off)
        XCTAssertEqual(MacosNonNativeFullscreen(rawValue: "true"), .on)
        XCTAssertEqual(MacosNonNativeFullscreen(rawValue: "visible-menu"), .visibleMenu)
        XCTAssertEqual(MacosNonNativeFullscreen(rawValue: "padded-notch"), .paddedNotch)
    }

    func testNonNativeFullscreenSerialization() {
        XCTAssertEqual(MacosNonNativeFullscreen.off.rawValue, "false")
        XCTAssertEqual(MacosNonNativeFullscreen.on.rawValue, "true")
        XCTAssertEqual(MacosNonNativeFullscreen.visibleMenu.rawValue, "visible-menu")
        XCTAssertEqual(MacosNonNativeFullscreen.paddedNotch.rawValue, "padded-notch")
    }

    func testNonNativeFullscreenReadFromConfig() {
        let source = "macos-non-native-fullscreen = padded-notch\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosNonNativeFullscreen.self,
                                    for: "macos-non-native-fullscreen",
                                    default: .off)
        XCTAssertEqual(value, .paddedNotch)
    }

    func testNonNativeFullscreenFallsBackOnGarbage() {
        let source = "macos-non-native-fullscreen = banana\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let value = file.enumValue(MacosNonNativeFullscreen.self,
                                    for: "macos-non-native-fullscreen",
                                    default: .off)
        XCTAssertEqual(value, .off)
    }

    // MARK: - Other window enums

    func testWindowPaddingColorRawValues() {
        XCTAssertEqual(WindowPaddingColor(rawValue: "background"), .background)
        XCTAssertEqual(WindowPaddingColor(rawValue: "extend"), .extend)
        XCTAssertEqual(WindowPaddingColor(rawValue: "extend-always"), .extendAlways)
    }

    func testResizeOverlayRawValues() {
        XCTAssertEqual(ResizeOverlay(rawValue: "always"), .always)
        XCTAssertEqual(ResizeOverlay(rawValue: "never"), .never)
        XCTAssertEqual(ResizeOverlay(rawValue: "after-first"), .afterFirst)
    }

    func testWindowNewTabPositionRawValues() {
        XCTAssertEqual(WindowNewTabPosition(rawValue: "current"), .current)
        XCTAssertEqual(WindowNewTabPosition(rawValue: "end"), .end)
    }

    func testMacosTitlebarProxyIconRawValues() {
        XCTAssertEqual(MacosTitlebarProxyIcon(rawValue: "visible"), .visible)
        XCTAssertEqual(MacosTitlebarProxyIcon(rawValue: "hidden"), .hidden)
    }
}

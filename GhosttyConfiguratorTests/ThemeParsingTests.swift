@testable import GhosttyConfigurator
import XCTest

final class ThemeParsingTests: XCTestCase {
    // MARK: - ColorParsing

    func testHexFullForm() {
        let rgb = ColorParsing.rgbComponents(from: "#1e1e2e")
        XCTAssertEqual(rgb?.r, 0x1E)
        XCTAssertEqual(rgb?.g, 0x1E)
        XCTAssertEqual(rgb?.b, 0x2E)
    }

    func testHexWithoutHash() {
        let rgb = ColorParsing.rgbComponents(from: "ff8800")
        XCTAssertEqual(rgb?.r, 0xFF)
        XCTAssertEqual(rgb?.g, 0x88)
        XCTAssertEqual(rgb?.b, 0x00)
    }

    func testShortHexExpands() {
        let rgb = ColorParsing.rgbComponents(from: "#fa3")
        XCTAssertEqual(rgb?.r, 0xFF)
        XCTAssertEqual(rgb?.g, 0xAA)
        XCTAssertEqual(rgb?.b, 0x33)
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(ColorParsing.rgbComponents(from: "not-a-color"))
        XCTAssertNil(ColorParsing.rgbComponents(from: "#xyzxyz"))
        XCTAssertNil(ColorParsing.rgbComponents(from: ""))
    }

    func testIsDark() {
        XCTAssertEqual(ColorParsing.isDark("#000000"), true)
        XCTAssertEqual(ColorParsing.isDark("#FFFFFF"), false)
        XCTAssertEqual(ColorParsing.isDark("#1e1e2e"), true, "Catppuccin Mocha bg")
        XCTAssertEqual(ColorParsing.isDark("#fffcf0"), false, "Flexoki Light bg")
    }

    // MARK: - ThemePair

    func testThemePairSingleValue() {
        let pair = ThemePair(parsing: "Catppuccin Mocha")
        XCTAssertEqual(pair.single, "Catppuccin Mocha")
        XCTAssertNil(pair.light)
        XCTAssertNil(pair.dark)
        XCTAssertFalse(pair.isPair)
    }

    func testThemePairLightDarkUnquoted() {
        let pair = ThemePair(parsing: "light:Solarized Light,dark:Solarized Dark")
        XCTAssertEqual(pair.light, "Solarized Light")
        XCTAssertEqual(pair.dark, "Solarized Dark")
        XCTAssertNil(pair.single)
        XCTAssertTrue(pair.isPair)
    }

    func testThemePairLightDarkQuoted() {
        // The exact value from Goutham's real config.
        let pair = ThemePair(parsing: "light:\"Flexoki Light\",dark:\"Flexoki Dark\"")
        XCTAssertEqual(pair.light, "Flexoki Light")
        XCTAssertEqual(pair.dark, "Flexoki Dark")
        XCTAssertTrue(pair.isPair)
    }

    func testThemePairSerializeRoundTrip() {
        let original = "light:\"Flexoki Light\",dark:\"Flexoki Dark\""
        let pair = ThemePair(parsing: original)
        XCTAssertEqual(pair.serialized(), original)
    }

    func testThemePairEmptyParsesAsEmpty() {
        let pair = ThemePair(parsing: nil)
        XCTAssertNil(pair.single)
        XCTAssertNil(pair.light)
        XCTAssertNil(pair.dark)
        XCTAssertFalse(pair.isPair)
    }
}

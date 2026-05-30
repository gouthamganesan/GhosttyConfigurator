import XCTest
import SwiftUI
@testable import GhosttyConfigurator

/// Round-trip coverage for the Colors section of AppearancePane (A1):
/// - hex parse + serialize symmetry
/// - bold-color tri-state derivation from the raw config value
final class ColorRoundTripTests: XCTestCase {

    // MARK: - Hex parse/serialize

    func testHexRoundTrip() {
        let cases = ["#000000", "#FFFFFF", "#1D1F21", "#AB12CD"]
        for hex in cases {
            guard let color = ColorParsing.color(from: hex) else {
                XCTFail("Failed to parse \(hex)")
                continue
            }
            let serialized = ColorParsing.hexString(from: color)
            XCTAssertEqual(serialized.uppercased(), hex.uppercased(),
                           "Round-trip changed value: \(hex) → \(serialized)")
        }
    }

    func testShortHexExpands() {
        guard let color = ColorParsing.color(from: "#abc") else {
            return XCTFail("Failed to parse short hex")
        }
        XCTAssertEqual(ColorParsing.hexString(from: color), "#AABBCC")
    }

    func testInvalidHexReturnsNil() {
        XCTAssertNil(ColorParsing.color(from: "not-a-color"))
        XCTAssertNil(ColorParsing.color(from: "#ZZZZZZ"))
        XCTAssertNil(ColorParsing.color(from: "#12345"))
    }

    // MARK: - bold-color mode derivation

    func testBoldColorModeNoneWhenAbsent() {
        let file = ConfigFile(parsed: ConfigParser.parse(""))
        XCTAssertEqual(file.boldColorMode(), .none)
    }

    func testBoldColorModeBrightLiteral() {
        let file = ConfigFile(parsed: ConfigParser.parse("bold-color = bright\n"))
        XCTAssertEqual(file.boldColorMode(), .bright)
    }

    func testBoldColorModeCustomFromHex() {
        let file = ConfigFile(parsed: ConfigParser.parse("bold-color = #abcdef\n"))
        XCTAssertEqual(file.boldColorMode(), .custom)
    }

    func testBoldColorModeNoneOnInvalidValue() {
        let file = ConfigFile(parsed: ConfigParser.parse("bold-color = banana\n"))
        XCTAssertEqual(file.boldColorMode(), .none)
    }

    func testBoldColorModeLastWriteWins() {
        // Ghostty applies last-write-wins to scalar keys.
        let source = "bold-color = bright\nbold-color = #112233\n"
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        XCTAssertEqual(file.boldColorMode(), .custom)
    }
}

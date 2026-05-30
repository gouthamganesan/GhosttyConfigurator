@testable import GhosttyConfigurator
import XCTest

/// Round-trip coverage for the Font pane numerals picker (B2). The picker
/// is exclusive: setting one numerals tag clears the other three. Existing
/// liga/calt features must survive the mutation.
final class FontNumeralsTests: XCTestCase {
    func testNumeralsDefaultWhenNoTags() {
        let file = ConfigFile(parsed: ConfigParser.parse("font-feature = +liga\n"))
        XCTAssertEqual(file.fontNumerals(), .default)
    }

    func testNumeralsReadTabular() {
        let file = ConfigFile(parsed: ConfigParser.parse("font-feature = +tnum\n"))
        XCTAssertEqual(file.fontNumerals(), .tabular)
    }

    func testNumeralsReadOldStyle() {
        let file = ConfigFile(parsed: ConfigParser.parse("font-feature = +onum\n"))
        XCTAssertEqual(file.fontNumerals(), .oldStyle)
    }

    func testNumeralsLastWriteWinsAcrossModes() {
        let source = """
        font-feature = +tnum
        font-feature = +pnum
        """
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        XCTAssertEqual(file.fontNumerals(), .proportional)
    }

    func testSetNumeralsClearsOtherTags() {
        var file = ConfigFile(parsed: ConfigParser.parse("font-feature = +liga\nfont-feature = +tnum\n"))
        file.setFontNumerals(.oldStyle)
        let values = file.listValues(for: "font-feature")
        XCTAssertTrue(values.contains("+liga"), "Existing liga feature must survive")
        XCTAssertTrue(values.contains("+onum"), "New onum tag should be present")
        XCTAssertFalse(values.contains("+tnum"), "Old tnum tag must be removed")
        XCTAssertFalse(values.contains("+pnum"))
        XCTAssertFalse(values.contains("+lnum"))
    }

    func testSetNumeralsToDefaultRemovesAll() {
        var file = ConfigFile(parsed: ConfigParser.parse("font-feature = +tnum\nfont-feature = +liga\n"))
        file.setFontNumerals(.default)
        let values = file.listValues(for: "font-feature")
        XCTAssertEqual(values, ["+liga"], "Only non-numerals features should remain")
    }

    func testSetNumeralsRemovesNegatedTagsToo() {
        // A -tag form should also be cleared so we don't end up with conflicting state.
        var file = ConfigFile(parsed: ConfigParser.parse("font-feature = -tnum\n"))
        file.setFontNumerals(.proportional)
        let values = file.listValues(for: "font-feature")
        XCTAssertEqual(values, ["+pnum"])
    }

    func testNumeralsRawValuesMatchOpenTypeTags() {
        XCTAssertEqual(FontNumerals.tabular.rawValue, "tnum")
        XCTAssertEqual(FontNumerals.proportional.rawValue, "pnum")
        XCTAssertEqual(FontNumerals.oldStyle.rawValue, "onum")
        XCTAssertEqual(FontNumerals.lining.rawValue, "lnum")
    }
}

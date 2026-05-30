@testable import GhosttyConfigurator
import XCTest

/// Round-trip coverage for the Shell pane env vars editor (B3). The editor
/// rewrites the whole list each commit, so we cover parse + serialize plus
/// drop-malformed behavior.
final class EnvVarTests: XCTestCase {
    // MARK: - parse

    func testParseBasic() {
        let v = EnvVar.parse("FOO=bar")
        XCTAssertEqual(v?.key, "FOO")
        XCTAssertEqual(v?.value, "bar")
    }

    func testParseAllowsEmptyValue() {
        // `env = FOO=` is Ghostty's "remove FOO from environment" form;
        // we still parse it as a valid entry the editor can show.
        let v = EnvVar.parse("FOO=")
        XCTAssertEqual(v?.key, "FOO")
        XCTAssertEqual(v?.value, "")
    }

    func testParseAllowsEqualsInValue() {
        // `KEY=a=b` should give value `a=b` (only the first `=` splits).
        let v = EnvVar.parse("KEY=a=b")
        XCTAssertEqual(v?.key, "KEY")
        XCTAssertEqual(v?.value, "a=b")
    }

    func testParseRejectsMissingEquals() {
        XCTAssertNil(EnvVar.parse("JUST_A_KEY"))
    }

    func testParseRejectsEmptyKey() {
        XCTAssertNil(EnvVar.parse("=value"))
    }

    func testParseTrimsKeyWhitespace() {
        let v = EnvVar.parse("  FOO  =bar")
        XCTAssertEqual(v?.key, "FOO")
        XCTAssertEqual(v?.value, "bar")
    }

    // MARK: - ConfigFile.envVars()

    func testReadEnvVarsInSourceOrder() {
        let source = """
        env = FOO=bar
        env = BAZ=qux
        """
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let vars = file.envVars()
        XCTAssertEqual(vars.map(\.key), ["FOO", "BAZ"])
        XCTAssertEqual(vars.map(\.value), ["bar", "qux"])
    }

    func testReadEnvVarsDropsMalformed() {
        let source = """
        env = FOO=bar
        env = bad_no_equals
        env = =empty_key
        env = OK=yes
        """
        let file = ConfigFile(parsed: ConfigParser.parse(source))
        let vars = file.envVars()
        XCTAssertEqual(vars.map(\.key), ["FOO", "OK"])
    }

    // MARK: - serialize

    func testSerializedForm() {
        XCTAssertEqual(EnvVar(key: "FOO", value: "bar").serialized, "FOO=bar")
        XCTAssertEqual(EnvVar(key: "FOO", value: "").serialized, "FOO=")
    }

    // MARK: - Equality ignores id

    func testEqualityIgnoresID() {
        let a = EnvVar(id: UUID(), key: "FOO", value: "bar")
        let b = EnvVar(id: UUID(), key: "FOO", value: "bar")
        XCTAssertEqual(a, b)
    }
}

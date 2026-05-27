import Foundation
import XCTest

/// Helpers for loading fixture .ghostty files bundled into the test target.
enum Fixtures {
    /// Read the named fixture as a String (preserves byte content including
    /// CRLF line endings).
    static func string(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let bundle = Bundle(for: FixturesAnchor.self)
        guard let url = bundle.url(forResource: name, withExtension: "ghostty", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "ghostty") else {
            XCTFail("Fixture \(name).ghostty not found in test bundle", file: file, line: line)
            throw FixtureError.notFound(name)
        }
        let data = try Data(contentsOf: url)
        return String(decoding: data, as: UTF8.self)
    }

    enum FixtureError: Error {
        case notFound(String)
    }

    private final class FixturesAnchor {}
}

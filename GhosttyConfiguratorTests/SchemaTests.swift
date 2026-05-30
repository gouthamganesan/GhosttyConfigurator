@testable import GhosttyConfigurator
import XCTest

final class SchemaTests: XCTestCase {
    func testParsesCommentBlockThenKey() {
        let input = """
        # The font families to use.
        # Generate with `ghostty +list-fonts`.
        font-family = JetBrains Mono

        # Cursor style.
        cursor-style = block
        """
        let entries = SchemaStore.parse(input)
        XCTAssertEqual(entries["font-family"]?.defaultValue, "JetBrains Mono")
        XCTAssertEqual(
            entries["font-family"]?.docs,
            "The font families to use. Generate with `ghostty +list-fonts`."
        )
        XCTAssertEqual(entries["cursor-style"]?.defaultValue, "block")
        XCTAssertEqual(entries["cursor-style"]?.docs, "Cursor style.")
    }

    func testParagraphBreakBetweenBlankCommentLines() {
        let input = """
        # First paragraph line 1.
        # First paragraph line 2.
        #
        # Second paragraph.
        font-size = 13
        """
        let entries = SchemaStore.parse(input)
        XCTAssertEqual(
            entries["font-size"]?.docs,
            "First paragraph line 1. First paragraph line 2.\n\nSecond paragraph."
        )
    }

    func testEmptyDefaultValue() {
        let input = """
        # No default.
        title =
        """
        let entries = SchemaStore.parse(input)
        XCTAssertNotNil(entries["title"])
        XCTAssertEqual(entries["title"]?.defaultValue, "")
    }

    func testRealOutputProducesManyEntries() {
        let cliPath = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
        guard FileManager.default.fileExists(atPath: cliPath) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = ["+show-config", "--default", "--docs"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)

        let entries = SchemaStore.parse(output)
        XCTAssertGreaterThan(
            entries.count,
            100,
            "Expected the real Ghostty schema to expose >100 keys; got \(entries.count)"
        )
        for key in ["font-family", "font-size", "background", "theme", "cursor-style"] {
            XCTAssertNotNil(entries[key], "Missing expected key '\(key)' in real schema")
        }
    }
}

import XCTest
@testable import AST_plus

final class REPLParserTests: XCTestCase {
    func testParseModeCommand() throws {
        let command = try REPLCommandParser.parse("/mode deep")

        switch command {
        case .setMode(let mode):
            XCTAssertEqual(mode, .deep)
        default:
            XCTFail("Expected .setMode")
        }
    }

    func testParseLogWindowCommand() throws {
        let command = try REPLCommandParser.parse("/set log-window 24h")

        switch command {
        case .setLogWindow(let value):
            XCTAssertEqual(value, "24h")
        default:
            XCTFail("Expected .setLogWindow")
        }
    }

    func testNaturalLanguageFallsBackToText() throws {
        let command = try REPLCommandParser.parse("run a quick check")

        switch command {
        case .text(let value):
            XCTAssertEqual(value, "run a quick check")
        default:
            XCTFail("Expected .text")
        }
    }

    func testParseRunWithModeOverride() throws {
        let command = try REPLCommandParser.parse("/run auto")

        switch command {
        case .run(let mode):
            XCTAssertEqual(mode, .auto)
        default:
            XCTFail("Expected .run")
        }
    }
}

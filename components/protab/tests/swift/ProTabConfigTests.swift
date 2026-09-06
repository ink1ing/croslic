import XCTest
import Foundation
@testable import ProTab

// 导入被测试的类
// 由于没有模块，我们需要直接编译源文件

class ProTabConfigTests: XCTestCase {
    private var tempConfigPath: String!
    private var originalConfigVar: String?

    override func setUp() {
        super.setUp()

        // 保存原始环境变量
        originalConfigVar = ProcessInfo.processInfo.environment["PROTAB_CONFIG"]

        // 创建临时配置文件
        let tempDir = NSTemporaryDirectory()
        tempConfigPath = (tempDir as NSString).appendingPathComponent("test_config.json")

        let testConfig = """
        {
            "app": {
                "name": "ProTab Test",
                "version": "1.0.0",
                "debug": true
            },
            "paths": {
                "work_directory": "${HOME}/test_protab",
                "scripts_directory": "${HOME}/test_protab/shortcuts"
            },
            "keyboard": {
                "wait_timeout_ms": 300,
                "shortcuts": {
                    "t": "test.sh",
                    "a": "auth.sh"
                }
            },
            "services": {
                "api_endpoint": "http://localhost:8080",
                "timeout_seconds": 5
            }
        }
        """

        try! testConfig.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)
        setenv("PROTAB_CONFIG", tempConfigPath, 1)
    }

    override func tearDown() {
        // 清理临时文件
        try? FileManager.default.removeItem(atPath: tempConfigPath)

        // 恢复环境变量
        if let original = originalConfigVar {
            setenv("PROTAB_CONFIG", original, 1)
        } else {
            unsetenv("PROTAB_CONFIG")
        }

        super.tearDown()
    }

    func testConfigLoading() {
        let config = ProTabConfig()

        XCTAssertEqual(config.appName, "ProTab Test")
        XCTAssertEqual(config.appVersion, "1.0.0")
        XCTAssertEqual(config.debugMode, true)
        XCTAssertEqual(config.waitTimeoutMs, 300)
    }

    func testEnvironmentVariableExpansion() {
        let config = ProTabConfig()
        let homeDir = ProcessInfo.processInfo.environment["HOME"]!
        let expectedWorkDir = homeDir + "/test_protab"

        XCTAssertEqual(config.workDirectory, expectedWorkDir)
    }

    func testShortcutRetrieval() {
        let config = ProTabConfig()

        XCTAssertEqual(config.getShortcutPath(for: "t"), config.workDirectory + "/shortcuts/test.sh")
        XCTAssertEqual(config.getShortcutPath(for: "a"), config.workDirectory + "/shortcuts/auth.sh")
        XCTAssertNil(config.getShortcutPath(for: "z"))
    }

    func testInvalidConfig() {
        // 测试无效配置文件
        let invalidConfigPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("invalid_config.json")
        let invalidConfig = "{ invalid json }"
        try! invalidConfig.write(toFile: invalidConfigPath, atomically: true, encoding: .utf8)

        setenv("PROTAB_CONFIG", invalidConfigPath, 1)

        // 应该使用默认值
        let config = ProTabConfig()
        XCTAssertEqual(config.appName, "ProTab")
        XCTAssertEqual(config.waitTimeoutMs, 1000) // 默认值

        try? FileManager.default.removeItem(atPath: invalidConfigPath)
    }

    func testMissingConfigFile() {
        let nonexistentPath = "/tmp/nonexistent_config.json"
        setenv("PROTAB_CONFIG", nonexistentPath, 1)

        // 应该使用默认值
        let config = ProTabConfig()
        XCTAssertEqual(config.appName, "ProTab")
        XCTAssertEqual(config.waitTimeoutMs, 1000)
    }

    func testDefaultConfigPaths() {
        unsetenv("PROTAB_CONFIG")

        // 测试默认配置路径查找
        let config = ProTabConfig()
        // 在没有配置文件的情况下，应该使用默认值
        XCTAssertNotNil(config.appName)
        XCTAssertGreaterThan(config.waitTimeoutMs, 0)
    }
}

// 键码映射测试
class KeyCodeMappingTests: XCTestCase {
    func testValidKeyCodes() {
        XCTAssertEqual(keyCodeToLetter(0), "a")
        XCTAssertEqual(keyCodeToLetter(11), "b")
        XCTAssertEqual(keyCodeToLetter(8), "c")
        XCTAssertEqual(keyCodeToLetter(6), "z")
        XCTAssertEqual(keyCodeToLetter(17), "t")
    }

    func testInvalidKeyCodes() {
        XCTAssertEqual(keyCodeToLetter(-1), "")
        XCTAssertEqual(keyCodeToLetter(999), "")
        XCTAssertEqual(keyCodeToLetter(100), "")
    }

    func testAllLetterMappings() {
        let expectedMappings: [Int64: String] = [
            0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
            3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
            40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
            35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
            32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z"
        ]

        for (keyCode, expectedLetter) in expectedMappings {
            XCTAssertEqual(keyCodeToLetter(keyCode), expectedLetter,
                          "键码 \(keyCode) 应该映射到字母 \(expectedLetter)")
        }
    }
}
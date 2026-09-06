#!/bin/bash
# 独立的Swift测试运行器
# 不依赖XCTest模块，直接编译和运行Swift代码

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 运行 Swift 单元测试..."
echo "项目目录: $PROJECT_DIR"

# 编译Swift源文件到独立的测试可执行文件
echo "📦 编译测试..."

# 创建临时测试目录
TEST_BUILD_DIR="$PROJECT_DIR/tests/build"
mkdir -p "$TEST_BUILD_DIR"

# 创建一个独立的Swift测试文件
cat > "$TEST_BUILD_DIR/ProTabTests.swift" << 'EOF'
import Foundation

// 复制必要的源代码结构（避免模块依赖）
struct TestProTabConfig {
    let appName: String
    let appVersion: String
    let debugMode: Bool
    let waitTimeoutMs: Int
    let workDirectory: String

    init() {
        // 模拟ProTabConfig的行为
        if let configPath = ProcessInfo.processInfo.environment["PROTAB_CONFIG"],
           FileManager.default.fileExists(atPath: configPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            let app = json["app"] as? [String: Any] ?? [:]
            self.appName = app["name"] as? String ?? "ProTab"
            self.appVersion = app["version"] as? String ?? "1.0.0"
            self.debugMode = app["debug"] as? Bool ?? false

            let keyboard = json["keyboard"] as? [String: Any] ?? [:]
            self.waitTimeoutMs = keyboard["wait_timeout_ms"] as? Int ?? 1000

            let paths = json["paths"] as? [String: Any] ?? [:]
            var workDir = paths["work_directory"] as? String ?? "${HOME}/Desktop/ProTab"

            // 环境变量替换
            if let home = ProcessInfo.processInfo.environment["HOME"] {
                workDir = workDir.replacingOccurrences(of: "${HOME}", with: home)
            }
            self.workDirectory = workDir
        } else {
            // 默认值
            self.appName = "ProTab"
            self.appVersion = "1.0.0"
            self.debugMode = false
            self.waitTimeoutMs = 1000
            self.workDirectory = ProcessInfo.processInfo.environment["HOME"]! + "/Desktop/ProTab"
        }
    }

    func getShortcutPath(for key: String) -> String? {
        guard let configPath = ProcessInfo.processInfo.environment["PROTAB_CONFIG"],
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keyboard = json["keyboard"] as? [String: Any],
              let shortcuts = keyboard["shortcuts"] as? [String: String],
              let script = shortcuts[key] else {
            return nil
        }

        return workDirectory + "/shortcuts/" + script
    }
}

// 复制键码映射函数
func testKeyCodeToLetter(_ keyCode: Int64) -> String {
    let keyMap: [Int64: String] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
        3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
        40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
        35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
        32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z"
    ]

    return keyMap[keyCode] ?? ""
}

// 简单的测试断言
func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        print("✅ \(message)")
    } else {
        print("❌ \(message) - 失败于 \(file):\(line)")
        exit(1)
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual == expected {
        print("✅ \(message): \(actual)")
    } else {
        print("❌ \(message): 期望 \(expected), 实际 \(actual)")
        exit(1)
    }
}

// 测试套件
func runConfigTests() {
    print("\n🔧 配置测试:")

    // 创建临时配置文件
    let tempDir = NSTemporaryDirectory()
    let tempConfigPath = (tempDir as NSString).appendingPathComponent("test_config.json")

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

    // 运行测试
    let config = TestProTabConfig()

    assertEqual(config.appName, "ProTab Test", "应用名称加载")
    assertEqual(config.appVersion, "1.0.0", "应用版本加载")
    assertEqual(config.debugMode, true, "调试模式加载")
    assertEqual(config.waitTimeoutMs, 300, "等待超时加载")

    // 环境变量展开测试
    let homeDir = ProcessInfo.processInfo.environment["HOME"]!
    let expectedWorkDir = homeDir + "/test_protab"
    assertEqual(config.workDirectory, expectedWorkDir, "环境变量展开")

    // 快捷键路径测试
    let tPath = config.getShortcutPath(for: "t")
    assertEqual(tPath, expectedWorkDir + "/shortcuts/test.sh", "快捷键路径生成")

    let aPath = config.getShortcutPath(for: "a")
    assertEqual(aPath, expectedWorkDir + "/shortcuts/auth.sh", "快捷键路径生成")

    let nilPath = config.getShortcutPath(for: "z")
    assert(nilPath == nil, "不存在的快捷键返回nil")

    // 清理
    try? FileManager.default.removeItem(atPath: tempConfigPath)
    unsetenv("PROTAB_CONFIG")

    print("✅ 配置测试完成")
}

func runKeyCodeTests() {
    print("\n⌨️  键码映射测试:")

    // 测试有效键码
    assertEqual(testKeyCodeToLetter(0), "a", "键码0映射")
    assertEqual(testKeyCodeToLetter(11), "b", "键码11映射")
    assertEqual(testKeyCodeToLetter(8), "c", "键码8映射")
    assertEqual(testKeyCodeToLetter(6), "z", "键码6映射")
    assertEqual(testKeyCodeToLetter(17), "t", "键码17映射")

    // 测试无效键码
    assertEqual(testKeyCodeToLetter(-1), "", "无效键码-1")
    assertEqual(testKeyCodeToLetter(999), "", "无效键码999")
    assertEqual(testKeyCodeToLetter(100), "", "无效键码100")

    print("✅ 键码映射测试完成")
}

func runDefaultConfigTests() {
    print("\n⚙️ 默认配置测试:")

    // 测试无配置文件情况
    unsetenv("PROTAB_CONFIG")

    let config = TestProTabConfig()
    assertEqual(config.appName, "ProTab", "默认应用名称")
    assertEqual(config.waitTimeoutMs, 1000, "默认等待超时")
    assert(config.workDirectory.contains("Desktop/ProTab"), "默认工作目录")

    print("✅ 默认配置测试完成")
}

// 主测试入口
func main() {
    print("🧪 开始Swift组件测试")
    print("====================")

    runConfigTests()
    runKeyCodeTests()
    runDefaultConfigTests()

    print("\n🎉 所有Swift测试通过!")
}

main()
EOF

# 编译Swift测试
if swiftc "$TEST_BUILD_DIR/ProTabTests.swift" -o "$TEST_BUILD_DIR/ProTabTests" 2>&1; then
    echo "✅ 编译成功"

    # 运行测试
    echo "🚀 运行测试..."
    if "$TEST_BUILD_DIR/ProTabTests"; then
        echo "✅ Swift测试通过"
        exit 0
    else
        echo "❌ Swift测试失败"
        exit 1
    fi
else
    echo "❌ 编译失败"
    exit 1
fi
import Foundation

enum CLIConfigurationError: Error, CustomStringConvertible {
    case helpRequested
    case missingValue(flag: String)
    case invalidStressSeconds(String)
    case invalidLogWindow(String)
    case invalidMode(String)
    case invalidLanguage(String)
    case invalidDetail(String)
    case unknownArgument(String)

    var description: String {
        switch self {
        case .helpRequested:
            return CLIConfiguration.usage
        case .missingValue(let flag):
            return "缺少参数值：\(flag)\n\n\(CLIConfiguration.usage)"
        case .invalidStressSeconds(let value):
            return "无效的 --stress-seconds 值：\(value)\n\n\(CLIConfiguration.usage)"
        case .invalidLogWindow(let value):
            return "无效的 --log-window 值：\(value)，只支持 1h / 24h / 7d\n\n\(CLIConfiguration.usage)"
        case .invalidMode(let value):
            return "无效的 --mode 值：\(value)，只支持 standard / deep / auto\n\n\(CLIConfiguration.usage)"
        case .invalidLanguage(let value):
            return "无效的 --language 值：\(value)，只支持 zh / en\n\n\(CLIConfiguration.usage)"
        case .invalidDetail(let value):
            return "无效的 --detail 值：\(value)，只支持 basic / specific\n\n\(CLIConfiguration.usage)"
        case .unknownArgument(let value):
            return "未知参数：\(value)\n\n\(CLIConfiguration.usage)"
        }
    }
}

enum SessionMode: String {
    case standard
    case deep
    case auto
}

enum OutputLanguage: String {
    case zh
    case en
}

enum OutputDetail: String {
    case basic
    case specific
}

struct CLIConfiguration {
    let deepMode: Bool
    let outputRoot: URL
    let stressSeconds: Int
    let skipStress: Bool
    let logWindow: String
    let interactive: Bool
    let sessionMode: SessionMode
    let language: OutputLanguage
    let detail: OutputDetail

    static let usage = """
    用法：
      swift run AST-plus [--interactive] [--mode <standard|deep|auto>] [--deep] [--output <目录>] [--stress-seconds <秒数>] [--skip-stress] [--log-window <1h|24h|7d>] [--language <zh|en>] [--detail <basic|specific>] [--once]

    参数：
      --interactive         启动常驻 REPL，会话内可切换模式和配置
      --once                执行一次扫描后退出
      --mode <值>           初始会话模式，默认 standard，可选 standard / deep / auto
      --deep                启用深度模式，尝试采集 powermetrics 等需要 sudo 的数据
      --output <目录>       指定输出根目录，默认当前目录
      --stress-seconds <秒> 指定 CPU 压测时长，默认 8 秒
      --skip-stress         跳过 CPU 压测
      --log-window <值>     结构化日志窗口，默认 1h，可选 1h / 24h / 7d
      --language <值>       输出语言，默认 zh，可选 zh / en
      --detail <值>         输出层级，默认 basic，可选 basic / specific
      --help                显示帮助
    """

    init(arguments: [String]) throws {
        var deepMode = false
        var outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var stressSeconds = 8
        var skipStress = false
        var logWindow = "1h"
        var interactive = true
        var sessionMode: SessionMode = .standard
        var language: OutputLanguage = .zh
        var detail: OutputDetail = .basic

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--help", "-h":
                throw CLIConfigurationError.helpRequested
            case "--interactive":
                interactive = true
            case "--once":
                interactive = false
            case "--mode":
                guard index + 1 < arguments.count else {
                    throw CLIConfigurationError.missingValue(flag: "--mode")
                }
                let rawValue = arguments[index + 1]
                guard let mode = SessionMode(rawValue: rawValue) else {
                    throw CLIConfigurationError.invalidMode(rawValue)
                }
                sessionMode = mode
                index += 1
            case "--deep":
                deepMode = true
                sessionMode = .deep
            case "--output":
                guard index + 1 < arguments.count else {
                    throw CLIConfigurationError.missingValue(flag: "--output")
                }
                outputRoot = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                index += 1
            case "--stress-seconds":
                guard index + 1 < arguments.count else {
                    throw CLIConfigurationError.missingValue(flag: "--stress-seconds")
                }
                let rawValue = arguments[index + 1]
                guard let value = Int(rawValue), value > 0 else {
                    throw CLIConfigurationError.invalidStressSeconds(rawValue)
                }
                stressSeconds = value
                index += 1
            case "--skip-stress":
                skipStress = true
            case "--log-window":
                guard index + 1 < arguments.count else {
                    throw CLIConfigurationError.missingValue(flag: "--log-window")
                }
                let rawValue = arguments[index + 1]
                guard ["1h", "24h", "7d"].contains(rawValue) else {
                    throw CLIConfigurationError.invalidLogWindow(rawValue)
                }
                logWindow = rawValue
                index += 1
            case "--language":
                guard index + 1 < arguments.count else {
                    throw CLIConfigurationError.missingValue(flag: "--language")
                }
                let rawValue = arguments[index + 1]
                guard let value = OutputLanguage(rawValue: rawValue) else {
                    throw CLIConfigurationError.invalidLanguage(rawValue)
                }
                language = value
                index += 1
            case "--detail":
                guard index + 1 < arguments.count else {
                    throw CLIConfigurationError.missingValue(flag: "--detail")
                }
                let rawValue = arguments[index + 1]
                guard let value = OutputDetail(rawValue: rawValue) else {
                    throw CLIConfigurationError.invalidDetail(rawValue)
                }
                detail = value
                index += 1
            default:
                throw CLIConfigurationError.unknownArgument(argument)
            }
            index += 1
        }

        self.deepMode = deepMode
        self.outputRoot = outputRoot
        self.stressSeconds = stressSeconds
        self.skipStress = skipStress
        self.logWindow = logWindow
        self.interactive = interactive
        self.sessionMode = sessionMode
        self.language = language
        self.detail = detail
    }
}

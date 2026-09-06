import Foundation

struct SessionState {
    var mode: SessionMode
    var stressSeconds: Int
    var skipStress: Bool
    var logWindow: String
    var lastRun: RunArtifacts?
    var previousRun: RunArtifacts?
}

enum REPLCommand {
    case help
    case exit
    case run(SessionMode?)
    case status
    case clear
    case last
    case diff
    case openReport
    case openJSON
    case openChecklist
    case setMode(SessionMode)
    case setStress(Int)
    case setSkipStress(Bool)
    case setLogWindow(String)
    case text(String)
}

enum REPLCommandParser {
    static func parse(_ input: String) throws -> REPLCommand {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .status
        }

        if !trimmed.hasPrefix("/") {
            return .text(trimmed)
        }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        switch parts.first {
        case "/help":
            return .help
        case "/exit", "/quit":
            return .exit
        case "/last":
            return .last
        case "/diff":
            return .diff
        case "/run":
            if let rawValue = parts.dropFirst().first {
                guard let mode = SessionMode(rawValue: rawValue) else {
                    throw CLIConfigurationError.invalidMode(rawValue)
                }
                return .run(mode)
            }
            return .run(nil)
        case "/status":
            return .status
        case "/clear":
            return .clear
        case "/open":
            switch parts.dropFirst().first {
            case "report":
                return .openReport
            case "json":
                return .openJSON
            case "checklist":
                return .openChecklist
            default:
                throw CLIConfigurationError.unknownArgument(trimmed)
            }
        case "/mode":
            guard let rawValue = parts.dropFirst().first, let mode = SessionMode(rawValue: rawValue) else {
                throw CLIConfigurationError.missingValue(flag: "/mode")
            }
            return .setMode(mode)
        case "/set":
            guard parts.count >= 3 else {
                throw CLIConfigurationError.unknownArgument(trimmed)
            }
            switch parts[1] {
            case "stress":
                guard let value = Int(parts[2]), value > 0 else {
                    throw CLIConfigurationError.invalidStressSeconds(parts[2])
                }
                return .setStress(value)
            case "skip-stress":
                return .setSkipStress(parts[2] == "on")
            case "log-window":
                guard ["1h", "24h", "7d"].contains(parts[2]) else {
                    throw CLIConfigurationError.invalidLogWindow(parts[2])
                }
                return .setLogWindow(parts[2])
            default:
                throw CLIConfigurationError.unknownArgument(trimmed)
            }
        default:
            throw CLIConfigurationError.unknownArgument(trimmed)
        }
    }
}

extension ASTPlusApp {
    func runInteractiveLoop() throws {
        var session = SessionState(
            mode: configuration.sessionMode,
            stressSeconds: configuration.stressSeconds,
            skipStress: configuration.skipStress,
            logWindow: configuration.logWindow,
            lastRun: nil,
            previousRun: nil
        )

        print("AST-plus interactive mode. 输入 /help 查看命令。")

        while true {
            let prompt = "ast-plus[\(session.mode.rawValue)]> "
            print(prompt, terminator: "")
            guard let line = readLine() else {
                print("")
                break
            }

            do {
                let command = try REPLCommandParser.parse(line)
                switch command {
                case .help:
                    printInteractiveHelp()
                case .exit:
                    return
                case .run(let modeOverride):
                    session = try runAndStore(session, modeOverride: modeOverride)
                case .status:
                    printSessionStatus(session)
                case .clear:
                    session.lastRun = nil
                    session.previousRun = nil
                    print("已清空当前会话中的上次运行记录。")
                case .last:
                    printLastRunSummary(session)
                case .diff:
                    printRunDiff(session)
                case .openReport:
                    print(session.lastRun?.reportMarkdown.path ?? "当前没有可用报告。")
                case .openJSON:
                    print(session.lastRun?.reportJSON.path ?? "当前没有可用 JSON 报告。")
                case .openChecklist:
                    print(session.lastRun?.checklist.path ?? "当前没有可用 checklist。")
                case .setMode(let mode):
                    session.mode = mode
                    print("当前模式：\(mode.rawValue)")
                case .setStress(let seconds):
                    session.stressSeconds = seconds
                    print("stressSeconds = \(seconds)")
                case .setSkipStress(let enabled):
                    session.skipStress = enabled
                    print("skipStress = \(enabled ? "on" : "off")")
                case .setLogWindow(let window):
                    session.logWindow = window
                    print("logWindow = \(window)")
                case .text(let text):
                    session = try handleNaturalInput(text, session: session)
                }
            } catch {
                print(error)
            }
        }
    }

    private func handleNaturalInput(_ text: String, session: SessionState) throws -> SessionState {
        let normalized = text.lowercased()
        if normalized.contains("run") || normalized.contains("scan") || normalized.contains("check") {
            return try runAndStore(session, modeOverride: nil)
        }
        print("自然语言当前只支持触发扫描。可直接输入 /run，或输入包含 run / scan / check 的句子。")
        return session
    }

    private func runAndStore(_ session: SessionState, modeOverride: SessionMode?) throws -> SessionState {
        var next = session
        let result = try runCurrentSession(session, modeOverride: modeOverride)
        next.previousRun = next.lastRun
        next.lastRun = result
        return next
    }

    private func runCurrentSession(_ session: SessionState, modeOverride: SessionMode?) throws -> RunArtifacts {
        try runScan(using: RunConfiguration(
            mode: modeOverride ?? session.mode,
            outputRoot: configuration.outputRoot,
            stressSeconds: session.stressSeconds,
            skipStress: session.skipStress,
            logWindow: session.logWindow,
            language: configuration.language,
            detail: configuration.detail
        ))
    }

    private func printInteractiveHelp() {
        print("""
        可用命令：
          /help
          /exit
          /run [standard|deep|auto]
          /status
          /last
          /diff
          /clear
          /mode standard|deep|auto
          /set stress <秒数>
          /set skip-stress on|off
          /set log-window 1h|24h|7d
          /open report|json|checklist
        """)
    }

    private func printSessionStatus(_ session: SessionState) {
        print("mode = \(session.mode.rawValue)")
        print("stressSeconds = \(session.stressSeconds)")
        print("skipStress = \(session.skipStress)")
        print("logWindow = \(session.logWindow)")
        if let lastRun = session.lastRun {
            print("lastOverallStatus = \(lastRun.report.overallStatus)")
            print("lastReport = \(lastRun.reportMarkdown.path)")
        } else {
            print("lastOverallStatus = none")
        }
    }

    private func printLastRunSummary(_ session: SessionState) {
        guard let lastRun = session.lastRun else {
            print("当前会话还没有运行记录。")
            return
        }

        print("lastOverallStatus = \(lastRun.report.overallStatus)")
        for item in lastRun.report.summary {
            print("- \(item)")
        }
    }

    private func printRunDiff(_ session: SessionState) {
        guard let previous = session.previousRun, let current = session.lastRun else {
            print("至少需要连续两次运行后才能对比。")
            return
        }

        let previousStatuses = moduleStatuses(from: previous.report)
        let currentStatuses = moduleStatuses(from: current.report)
        let keys = Array(Set(previousStatuses.keys).union(currentStatuses.keys)).sorted()

        print("diff: \(previous.report.overallStatus) -> \(current.report.overallStatus)")
        for key in keys {
            let before = previousStatuses[key] ?? "unknown"
            let after = currentStatuses[key] ?? "unknown"
            if before != after {
                print("- \(key): \(before) -> \(after)")
            }
        }
        if previous.report.overallStatus == current.report.overallStatus && keys.allSatisfy({ previousStatuses[$0] == currentStatuses[$0] }) {
            print("本次与上次模块状态没有变化。")
        }
    }

    private func moduleStatuses(from report: ASTPlusReport) -> [String: String] {
        [
            "hardware": report.hardware.status,
            "battery": report.battery.status,
            "storage": report.storage.status,
            "logs": report.logs.status,
            "peripherals": report.peripherals.status,
            "stress": report.stress.status,
            "deepMetrics": report.deepMetrics.status,
            "postStress": report.postStress.status
        ]
    }
}

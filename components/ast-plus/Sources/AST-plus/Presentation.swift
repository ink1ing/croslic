import Foundation

struct RenderOptions {
    let language: OutputLanguage
    let detail: OutputDetail
}

enum Presentation {
    static func text(_ zh: String, _ en: String, language: OutputLanguage) -> String {
        language == .zh ? zh : en
    }

    static func statusLabel(_ status: String, language: OutputLanguage) -> String {
        switch status {
        case "PASS":
            return text("正常 / 新机信号", "Normal / New", language: language)
        case "WARN":
            return text("使用痕迹 / 需复核", "Used / Review", language: language)
        case "FAIL":
            return text("异常 / 可疑", "Strange / Risk", language: language)
        default:
            return text("未知", "Unknown", language: language)
        }
    }

    static func reason(_ text: String, language: OutputLanguage) -> String {
        guard language == .en else { return text }

        switch text {
        case "检测到 Activation Lock 处于启用状态，交易前必须确认已退出所有者账户。":
            return "Activation Lock is enabled. Confirm the owner account has been removed before any transaction."
        case "机器身份字段完整，高层硬件信息可用于后续交叉校验。":
            return "Machine identity fields are complete and ready for cross-checking."
        case "关键机器身份字段缺失，无法建立可信基线。":
            return "Key machine identity fields are missing, so a trusted baseline cannot be established."
        case "电池关键字段可读取，当前未触发高风险阈值。":
            return "Battery key fields are readable and no high-risk threshold is currently triggered."
        case "系统已提示电池需要维修。":
            return "The system reports that the battery requires service."
        case "电池健康容量低于 85%，属于需要重点关注的范围。":
            return "Battery health capacity is below 85% and requires attention."
        case "循环次数较高，建议结合容量与温度继续复检。":
            return "Cycle count is relatively high. Recheck together with capacity and temperature."
        case "当前电池温度偏高，需结合负载与充电状态观察。":
            return "Battery temperature is elevated and should be reviewed with load and charging state."
        case "未能完整读取电池关键字段。":
            return "Failed to read complete battery key fields."
        case "当前机型无内置电池，此项不适用。":
            return "This machine has no built-in battery, so this item does not apply."
        case "已获取物理盘基础信息和 SMART 关键指标，当前未发现明确失败信号。":
            return "Physical disk basics and SMART indicators were collected, with no explicit failure signal."
        case "存储错误日志或异常断电计数偏高，建议结合压测与原始 SMART 数据复核。":
            return "Storage error counters or unsafe shutdown counts are elevated. Recheck with stress data and raw SMART values."
        case "检测到存储介质完整性错误，属于硬性红线。":
            return "Storage media integrity errors were detected. This is a hard red-line condition."
        case "NVMe 控制器已报告 SMART 失败。":
            return "The NVMe controller reports SMART failure."
        case "磁盘 SMART 已报告失败。":
            return "Disk SMART reports failure."
        case "SMART 状态非标准结果，建议进一步复检。":
            return "SMART status is non-standard and should be rechecked."
        case "未能读取到磁盘设备信息。":
            return "Failed to read disk device information."
        case "最近 7 天的 panic、I/O error 或异常关机日志中存在异常线索，需要人工复核原始证据。":
            return "Recent 7-day panic, I/O error, or shutdown-related logs contain suspicious signals and require manual review."
        case "最近 7 天的结构化日志中存在 GPU 或 NVMe 相关异常线索，需结合压测进一步确认。":
            return "Structured logs contain GPU or NVMe-related abnormal signals and should be confirmed with stress testing."
        case "最近 7 天的 panic 报告、结构化日志和电源日志未见明显异常。":
            return "No obvious abnormal signs were found in recent panic reports, structured logs, or power logs."
        case "基础外设已被系统识别，仍建议做人工交互复测。":
            return "Core peripherals are recognized by the system, but manual interaction tests are still recommended."
        case "CPU 标准压测已完成，未出现运行时中断。":
            return "The standard CPU stress test completed without runtime interruption."
        case "本次运行显式跳过了 CPU 压测。":
            return "The CPU stress test was explicitly skipped for this run."
        case "CPU 压测未正常完成。":
            return "The CPU stress test did not complete normally."
        case "本次未启用深度模式。":
            return "Deep mode was not enabled for this run."
        case "深度模式采集成功。":
            return "Deep mode collection succeeded."
        case "压测后异常断电计数发生变化，需复核存储与供电稳定性。":
            return "Unsafe shutdown counters changed after stress and storage/power stability should be rechecked."
        case "已完成压测前后关键指标采样，未见异常断电计数增长。":
            return "Pre/post stress sampling completed and unsafe shutdown counters did not increase."
        case "本次跳过压测，因此没有前后对比采样。":
            return "Stress testing was skipped, so there is no pre/post comparison sample."
        case "压测后采样不可用。":
            return "Post-stress sampling is unavailable."
        case "来源和维修类型无法仅靠当前软件结果 100% 确认；若交易敏感，建议到 Apple Genius Bar 或官方渠道进一步核验。":
            return "Source and repair type cannot be 100% confirmed from current software results alone. If the transaction is sensitive, go to Apple Genius Bar or an official channel for verification."
        default:
            return text
        }
    }

    static func progress(_ zh: String, _ en: String, language: OutputLanguage) -> String {
        text(zh, en, language: language)
    }
}

enum TerminalColor {
    static let reset = "\u{001B}[0m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let red = "\u{001B}[31m"
    static let cyan = "\u{001B}[36m"
    static let dim = "\u{001B}[2m"
}

enum TerminalReportRenderer {
    static func render(report: ASTPlusReport, options: RenderOptions, datedMarkdown: URL) -> String {
        let language = options.language
        var lines: [String] = []
        lines.append("\(TerminalColor.cyan)AST-plus\(TerminalColor.reset) \(Presentation.text("检测完成", "scan completed", language: language))")
        lines.append(summaryLine(title: Presentation.text("总体状态", "overall status", language: language), status: report.overallStatus, reason: nil, language: language))
        lines.append(Presentation.text("分类", "classification", language: language) + ": " + report.classification.originType + " / " + report.classification.usageState + " / " + report.classification.hardwareState + " / " + report.classification.lockState)
        lines.append(summaryLine(title: Presentation.text("硬件", "hardware", language: language), status: report.hardware.status, reason: report.hardware.reason, language: language))
        lines.append(summaryLine(title: Presentation.text("电池", "battery", language: language), status: report.battery.status, reason: report.battery.reason, language: language))
        lines.append(summaryLine(title: Presentation.text("存储", "storage", language: language), status: report.storage.status, reason: report.storage.reason, language: language))
        lines.append(summaryLine(title: Presentation.text("日志", "logs", language: language), status: report.logs.status, reason: report.logs.reason, language: language))
        lines.append(summaryLine(title: Presentation.text("压测", "stress", language: language), status: report.stress.status, reason: report.stress.reason, language: language))
        lines.append(summaryLine(title: Presentation.text("压测前后对比", "pre/post stress", language: language), status: report.postStress.status, reason: report.postStress.reason, language: language))
        lines.append(Presentation.text("保存报告", "saved report", language: language) + ": \(datedMarkdown.lastPathComponent)")
        return lines.joined(separator: "\n")
    }

    private static func summaryLine(title: String, status: String, reason: String?, language: OutputLanguage) -> String {
        let color: String
        switch status {
        case "PASS":
            color = TerminalColor.green
        case "WARN":
            color = TerminalColor.yellow
        case "FAIL":
            color = TerminalColor.red
        default:
            color = TerminalColor.yellow
        }
        let label = Presentation.statusLabel(status, language: language)
        if let reason {
            return "\(title): \(color)\(label)\(TerminalColor.reset) - \(Presentation.reason(reason, language: language))"
        }
        return "\(title): \(color)\(label)\(TerminalColor.reset)"
    }
}

enum TerminalProgressRenderer {
    static func stage(_ message: String) {
        print("\(TerminalColor.cyan)==>\(TerminalColor.reset) \(message)")
    }

    static func command(index: Int, total: Int, name: String, command: [String], language: OutputLanguage) {
        let prefix = language == .zh ? "采集中" : "Collecting"
        let renderedCommand = command.joined(separator: " ")
        print("\(TerminalColor.dim)[\(index)/\(total)]\(TerminalColor.reset) \(prefix) \(name)")
        print("\(TerminalColor.dim)    \(renderedCommand)\(TerminalColor.reset)")
    }

    static func commandFinished(name: String, exitCode: Int32, language: OutputLanguage) {
        let label = exitCode == 0
            ? Presentation.progress("完成", "done", language: language)
            : Presentation.progress("返回非零状态", "non-zero exit", language: language)
        let color = exitCode == 0 ? TerminalColor.green : TerminalColor.yellow
        print("\(color)\(label)\(TerminalColor.reset) \(name) (exit \(exitCode))")
    }
}

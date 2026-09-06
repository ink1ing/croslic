import Foundation

enum MarkdownReportRenderer {
    static func render(report: ASTPlusReport, options: RenderOptions) -> String {
        let language = options.language
        var lines: [String] = []

        lines.append("# " + Presentation.text("AST-plus 检测报告", "AST-plus Inspection Report", language: language))
        lines.append("")
        lines.append("- " + Presentation.text("生成时间", "Generated At", language: language) + "：\(report.generatedAt)")
        lines.append("- " + Presentation.text("机器名称", "Machine", language: language) + "：\(report.machineName)")
        lines.append("- " + Presentation.text("运行模式", "Mode", language: language) + "：\(report.mode)")
        lines.append("- " + Presentation.text("总体状态", "Overall Status", language: language) + "：" + statusBadge(report.overallStatus, language: language))
        lines.append("")
        lines.append("## " + Presentation.text("直接结论", "Direct Conclusion", language: language))
        lines.append("")
        for line in directConclusion(report: report, language: language) {
            lines.append("- \(line)")
        }
        lines.append("")
        lines.append("## " + Presentation.text("摘要", "Summary", language: language))
        lines.append("")
        for item in localizedSummary(report: report, language: language) {
            lines.append("- \(item)")
        }
        lines.append("")
        lines.append("## " + Presentation.text("分类判断", "Classification", language: language))
        lines.append("")
        lines.append("- `origin_type`: \(report.classification.originType)")
        lines.append("- `usage_state`: \(report.classification.usageState)")
        lines.append("- `hardware_state`: \(report.classification.hardwareState)")
        lines.append("- `lock_state`: \(report.classification.lockState)")
        lines.append("- " + Presentation.text("分类释义", "Classification Meaning", language: language) + "：")
        lines.append("  - `origin_type`: " + Presentation.text("来源判断，基于型号代码首字母和企业监管状态，属于启发式结果。", "Source judgment based on model-number prefix and enterprise enrollment state; this is heuristic rather than absolute proof.", language: language))
        lines.append("  - `usage_state`: " + Presentation.text("使用痕迹判断，笔记本主要依据电池循环次数，桌面机则更多参考 SSD 寿命、日志与压测结果。", "Usage-state judgment is mainly based on battery cycle count for notebooks, while desktop Macs rely more on SSD wear, logs, and stress results.", language: language))
        lines.append("  - `hardware_state`: " + Presentation.text("硬件状态判断。`no_clear_fault_signal` 表示未发现明确故障信号，`signal_present` 表示存在异常线索但不等于 100% 确认维修，`faulty` 表示故障信号明确。", "Hardware-state judgment. `no_clear_fault_signal` means no explicit fault signal was found, `signal_present` means abnormal signals exist but do not 100% prove repair history, and `faulty` means fault signals are explicit.", language: language))
        lines.append("  - `lock_state`: " + Presentation.text("锁状态判断，基于 Activation Lock 与 MDM / DEP 状态。", "Lock-state judgment based on Activation Lock and MDM / DEP state.", language: language))
        lines.append("- " + Presentation.text("置信度", "Confidence", language: language) + "：")
        for (key, value) in report.classification.confidence.sorted(by: { $0.key < $1.key }) {
            lines.append("  - `\(key)`: \(value)")
        }
        lines.append("- " + Presentation.text("证据", "Evidence", language: language) + "：")
        for item in report.classification.evidence {
            lines.append("  - `\(item)`")
        }
        lines.append("- " + Presentation.text("说明", "Note", language: language) + "：" + Presentation.reason(report.classification.note, language: language))
        lines.append("")

        let sections: [(String, String, ModuleReport)] = [
            ("hardware", Presentation.text("硬件基线", "Hardware", language: language), report.hardware),
            ("battery", Presentation.text("电池", "Battery", language: language), report.battery),
            ("storage", Presentation.text("存储", "Storage", language: language), report.storage),
            ("logs", Presentation.text("日志", "Logs", language: language), report.logs),
            ("peripherals", Presentation.text("外设", "Peripherals", language: language), report.peripherals),
            ("stress", Presentation.text("压测", "Stress", language: language), report.stress),
            ("deepMetrics", Presentation.text("深度采样", "Deep Metrics", language: language), report.deepMetrics),
            ("postStress", Presentation.text("压测前后对比", "Pre/Post Stress Comparison", language: language), report.postStress)
        ]

        for section in sections {
            lines.append(renderSection(section.0, title: section.1, report: section.2, options: options))
        }

        if options.detail == .specific {
            lines.append("## " + Presentation.text("检测条目明细", "Inspection Items", language: language))
            lines.append("")
            for item in inspectionItems(report: report, language: language) {
                lines.append(contentsOf: renderInspectionItem(item, language: language))
            }
        }

        lines.append("## " + Presentation.text("原始证据", "Artifacts", language: language))
        lines.append("")
        for artifact in report.artifacts {
            lines.append("- `\(artifact.name)` -> `artifacts/\(artifact.outputFile)`")
        }
        lines.append("")
        lines.append("## " + Presentation.text("结论建议", "Recommendation", language: language))
        lines.append("")
        lines.append("- " + Presentation.text("若总体状态为 `FAIL`：不建议购买或继续使用，先做进一步硬件复检。", "If overall status is `FAIL`: do not buy or continue using it before further hardware verification.", language: language))
        lines.append("- " + Presentation.text("若总体状态为 `WARN`：建议结合人工检查与 Apple Diagnostics 结果再判断。", "If overall status is `WARN`: review together with manual checks and Apple Diagnostics.", language: language))
        lines.append("- " + Presentation.text("若总体状态为 `PASS`：当前未发现明显高风险，但仍不代表 100% 无问题。", "If overall status is `PASS`: no obvious high-risk signal was found, but this still does not prove a 100% flawless machine.", language: language))
        return lines.joined(separator: "\n")
    }

    private static func directConclusion(report: ASTPlusReport, language: OutputLanguage) -> [String] {
        let hardware = report.hardware.rawValues
        let battery = report.battery.rawValues
        let storage = report.storage.rawValues
        let logs = report.logs.rawValues

        let machineType = Presentation.text("机器类型", "Machine Type", language: language) + "：" + describeMachineType(report: report, hardware: hardware, language: language)
        let usageState = Presentation.text("使用情况", "Usage", language: language) + "：" + describeUsage(report: report, battery: battery, storage: storage, language: language)
        let issues = Presentation.text("异常问题", "Abnormal Findings", language: language) + "：" + describeAbnormalIssues(report: report, hardware: hardware, storage: storage, logs: logs, language: language)
        let risks = Presentation.text("其他隐患", "Other Risks", language: language) + "：" + describeOtherRisks(report: report, language: language)

        return [machineType, usageState, issues, risks]
    }

    private static func renderSection(_ key: String, title: String, report: ModuleReport, options: RenderOptions) -> String {
        let language = options.language
        var lines: [String] = []
        lines.append("## \(title)")
        lines.append("")
        lines.append("- " + Presentation.text("状态", "Status", language: language) + "：" + statusBadge(report.status, language: language))
        lines.append("- " + Presentation.text("原因", "Reason", language: language) + "：" + Presentation.reason(report.reason, language: language))

        if options.detail == .specific {
            let highlightItems = highlights(for: key, report: report, language: language)
            if !highlightItems.isEmpty {
                lines.append("- " + Presentation.text("关键数据", "Key Data", language: language) + "：")
                for item in highlightItems {
                    lines.append("  - \(item)")
                }
            }

            let explanationItems = explanations(for: key, language: language)
            if !explanationItems.isEmpty {
                lines.append("- " + Presentation.text("项目说明", "What These Items Mean", language: language) + "：")
                for item in explanationItems {
                    lines.append("  - \(item)")
                }
            }

            lines.append("- " + Presentation.text("完整原始值", "Complete Raw Values", language: language) + "：")
            for (rawKey, value) in report.rawValues.sorted(by: { $0.key < $1.key }) {
                lines.append("  - `\(localizedKey(rawKey, language: language))`: \(value)")
            }
            lines.append("- " + Presentation.text("判定阈值", "Thresholds", language: language) + "：")
            for (thresholdKey, value) in report.thresholds.sorted(by: { $0.key < $1.key }) {
                lines.append("  - `\(thresholdKey)`: \(value)")
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func inspectionItems(report: ASTPlusReport, language: OutputLanguage) -> [InspectionItem] {
        let portable = isPortableMachine(report: report)
        let hardware = report.hardware.rawValues
        let battery = report.battery.rawValues
        let storage = report.storage.rawValues
        let logs = report.logs.rawValues
        let stress = report.stress.rawValues

        var items: [InspectionItem] = [
            InspectionItem(
                englishName: "Machine Type",
                actualData: report.classification.originType + " / model number \(hardware["model_number"] ?? "unknown")",
                chineseMeaning: Presentation.text("根据型号代码首字母，当前更接近零售机判断；但来源判断仍属于启发式，不等于官方来源证明。", "Based on the model-number prefix, this currently looks closer to a retail machine; source judgment remains heuristic rather than official proof.", language: language)
            ),
            InspectionItem(
                englishName: "Activation Lock",
                actualData: hardware["activation_lock_status"] ?? "unknown",
                chineseMeaning: Presentation.text("这是机器锁状态。若为启用状态，交易前必须确认原账号已退出，否则存在锁机风险。", "This is the machine lock state. If enabled, confirm the original account has been removed before any transaction.", language: language)
            )
        ]

        if portable {
            items.append(contentsOf: [
                InspectionItem(
                englishName: "Battery Cycle Count",
                actualData: valueWithUnit(battery["cycle_count"], unit: Presentation.text("次", "", language: language)),
                chineseMeaning: Presentation.text("电池循环次数，越低通常越接近新机。当前属于正常使用范围，不算高循环。", "Battery cycle count. Lower is usually closer to a new machine. The current value is within a normal-used range, not a high-cycle battery.", language: language)
            ),
                InspectionItem(
                englishName: "Battery Health Capacity",
                actualData: battery["max_capacity_percent"] ?? "unknown",
                chineseMeaning: Presentation.text("这是当前满充容量相对设计容量的比例。95% 说明电池健康度整体不错。", "This is the current full-charge capacity relative to design capacity. 95% indicates generally good battery health.", language: language)
            ),
                InspectionItem(
                englishName: "Battery Temperature",
                actualData: valueWithUnit(battery["temperature_celsius"], unit: "°C"),
                chineseMeaning: Presentation.text("电池当前温度，用来观察是否有异常发热。当前温度正常。", "Current battery temperature, used to observe abnormal heating. The current value looks normal.", language: language)
            )
            ])
        } else {
            items.append(
                InspectionItem(
                    englishName: "Battery",
                    actualData: "not_applicable",
                    chineseMeaning: Presentation.text("当前机型属于桌面机，没有内置电池，所以电池循环和电池健康不适用。", "This is a desktop Mac without a built-in battery, so battery cycle and health items do not apply.", language: language)
                )
            )
        }

        items.append(contentsOf: [
            InspectionItem(
                englishName: "SSD Percentage Used",
                actualData: valueWithUnit(storage["percentage_used"], unit: "%"),
                chineseMeaning: Presentation.text("这是 SSD 寿命消耗比例。数值越低越接近新盘，当前磨损很低。", "This is the SSD wear percentage. Lower means closer to a newer drive, and the current wear is low.", language: language)
            ),
            InspectionItem(
                englishName: "Unsafe Shutdowns",
                actualData: valueWithUnit(storage["unsafe_shutdowns"], unit: Presentation.text("次", "", language: language)),
                chineseMeaning: Presentation.text("这是 SSD 记录到的异常断电次数。45 次偏高，说明这台机器过去出现过较多非正常断电或强制关机痕迹。", "This is the SSD unsafe shutdown counter. A value of 45 is elevated and suggests a history of abnormal power loss or forced shutdowns.", language: language)
            ),
            InspectionItem(
                englishName: "SMART Status",
                actualData: storage["smart_status"] ?? "unknown",
                chineseMeaning: Presentation.text("这是磁盘健康自检结果。当前是 Verified，说明没有出现明确的硬盘故障信号。", "This is the disk self-check health result. The current value is Verified, meaning no explicit disk failure signal was found.", language: language)
            ),
            InspectionItem(
                englishName: "Panic Count",
                actualData: valueWithUnit(logs["panic_count"], unit: Presentation.text("个", "", language: language)),
                chineseMeaning: Presentation.text("最近 7 天内核崩溃相关报告数量。当前有 3 个，说明近期存在系统异常线索，需要结合原始日志复核。", "The number of kernel panic-related reports in the last 7 days. There are currently 3, which means recent abnormal system signals should be reviewed.", language: language)
            ),
            InspectionItem(
                englishName: "GPU Signal Count",
                actualData: valueWithUnit(logs["gpu_keyword_count"], unit: Presentation.text("个", "", language: language)),
                chineseMeaning: Presentation.text("最近日志中的 GPU 相关异常线索数量。当前有 4 个，表示出现过图形相关异常信号，但不等于已经确认硬件损坏。", "The number of GPU-related abnormal signals in recent logs. There are currently 4, indicating graphics-related abnormal signals but not confirmed hardware failure by itself.", language: language)
            ),
            InspectionItem(
                englishName: "I/O Error Count",
                actualData: valueWithUnit(logs["io_error_count"], unit: Presentation.text("个", "", language: language)),
                chineseMeaning: Presentation.text("磁盘 I/O 错误数量。当前为 0，说明没有看到直接的磁盘读写错误信号。", "The disk I/O error count. The current value is 0, meaning no direct read/write disk error signal was found.", language: language)
            ),
            InspectionItem(
                englishName: "CPU Stress Iterations",
                actualData: stress["iterations"] ?? "unknown",
                chineseMeaning: Presentation.text("CPU 压测完成的迭代次数，用来证明压测确实跑过。当前压测已完成且未中断。", "The number of CPU stress iterations completed, used to show the stress run actually executed. The current stress test completed without interruption.", language: language)
            ),
            InspectionItem(
                englishName: "Memory Probe",
                actualData: "bytes=\(stress["memory_bytes_tested"] ?? "unknown"), pass=\(stress["memory_pass"] ?? "unknown")",
                chineseMeaning: Presentation.text("这是基础内存探针结果。当前内存校验通过，说明轻量内存压力测试没有直接报错。", "This is the basic memory probe result. The current memory check passed, so the lightweight memory stress did not show an immediate error.", language: language)
            )
        ])

        return items
    }

    private static func renderInspectionItem(_ item: InspectionItem, language: OutputLanguage) -> [String] {
        [
            "### \(item.englishName)",
            "",
            "- " + Presentation.text("英文名称", "English Name", language: language) + "：`\(item.englishName)`",
            "- " + Presentation.text("实际数据", "Actual Data", language: language) + "：\(item.actualData)",
            "- " + Presentation.text("中文介绍", "Meaning", language: language) + "：\(item.chineseMeaning)",
            ""
        ]
    }

    private static func localizedSummary(report: ASTPlusReport, language: OutputLanguage) -> [String] {
        [
            "\(Presentation.text("硬件", "Hardware", language: language)): \(Presentation.statusLabel(report.hardware.status, language: language)) - \(Presentation.reason(report.hardware.reason, language: language))",
            "\(Presentation.text("电池", "Battery", language: language)): \(Presentation.statusLabel(report.battery.status, language: language)) - \(Presentation.reason(report.battery.reason, language: language))",
            "\(Presentation.text("存储", "Storage", language: language)): \(Presentation.statusLabel(report.storage.status, language: language)) - \(Presentation.reason(report.storage.reason, language: language))",
            "\(Presentation.text("日志", "Logs", language: language)): \(Presentation.statusLabel(report.logs.status, language: language)) - \(Presentation.reason(report.logs.reason, language: language))",
            "\(Presentation.text("压测", "Stress", language: language)): \(Presentation.statusLabel(report.stress.status, language: language)) - \(Presentation.reason(report.stress.reason, language: language))"
        ]
    }

    private static func describeMachineType(report: ASTPlusReport, hardware: [String: String], language: OutputLanguage) -> String {
        let modelNumber = hardware["model_number"] ?? "unknown"
        switch report.classification.originType {
        case "retail":
            return Presentation.text("倾向判断为零售机，型号代码为 \(modelNumber)。这是启发式判断，不等于官方来源认证。", "Likely a retail machine with model number \(modelNumber). This is heuristic and not official source certification.", language: language)
        case "refurbished":
            return Presentation.text("倾向判断为官方翻新机，型号代码为 \(modelNumber)。仍建议用官方渠道进一步核验。", "Likely an Apple refurbished machine with model number \(modelNumber). Official verification is still recommended.", language: language)
        case "service_replacement":
            return Presentation.text("倾向判断为售后置换机，型号代码为 \(modelNumber)。这不等于 100% 官方确认。", "Likely a service replacement machine with model number \(modelNumber). This is not 100% official confirmation.", language: language)
        case "configured_to_order":
            return Presentation.text("倾向判断为定制机，型号代码为 \(modelNumber)。", "Likely a configured-to-order machine with model number \(modelNumber).", language: language)
        case "enterprise":
            return Presentation.text("检测到企业监管信号，来源更接近企业机。", "Enterprise enrollment signals were detected, so the source looks closer to an enterprise machine.", language: language)
        default:
            return Presentation.text("当前无法仅靠软件结果准确确认机器来源。", "The machine source cannot be accurately confirmed from software results alone.", language: language)
        }
    }

    private static func describeUsage(report: ASTPlusReport, battery: [String: String], storage: [String: String], language: OutputLanguage) -> String {
        let portable = isPortableMachine(report: report)
        let cycle = battery["cycle_count"] ?? "unknown"
        let health = battery["max_capacity_percent"] ?? "unknown"
        let ssdWear = storage["percentage_used"] ?? "unknown"
        if !portable {
            switch report.classification.usageState {
            case "unused":
                return Presentation.text("更接近低使用桌面机，主要依据是 SSD 寿命消耗 \(ssdWear)% 且没有明显额外磨损信号。", "This looks closer to a lightly used desktop Mac, mainly based on SSD wear at \(ssdWear)% with no obvious extra wear signal.", language: language)
            case "light_use":
                return Presentation.text("属于轻度使用桌面机，当前主要依据是 SSD 寿命消耗 \(ssdWear)% 。", "This looks like a lightly used desktop Mac, mainly based on SSD wear at \(ssdWear)%.", language: language)
            case "normal_use":
                return Presentation.text("属于正常使用桌面机，当前主要依据是 SSD 寿命消耗 \(ssdWear)% 和日志/压测结果。", "This looks like a normally used desktop Mac, mainly based on SSD wear at \(ssdWear)% and the log/stress results.", language: language)
            case "heavy_use":
                return Presentation.text("使用痕迹较重，当前主要依据是 SSD 寿命消耗较高，建议重点复查散热、日志和稳定性。", "This looks more heavily used, mainly because SSD wear is higher; thermal, log, and stability checks are recommended.", language: language)
            default:
                return Presentation.text("当前无法完整判断这台桌面机的使用强度。", "The usage level of this desktop Mac cannot be fully determined from current data.", language: language)
            }
        }
        switch report.classification.usageState {
        case "unused":
            return Presentation.text("使用痕迹非常轻，电池循环 \(cycle) 次，电池健康 \(health)，SSD 寿命消耗 \(ssdWear)% ，接近未使用状态。", "Very light usage. Battery cycles: \(cycle), battery health: \(health), SSD wear: \(ssdWear)%, close to an unused state.", language: language)
        case "light_use":
            return Presentation.text("使用痕迹较轻，电池循环 \(cycle) 次，电池健康 \(health)，SSD 寿命消耗 \(ssdWear)% 。", "Light usage. Battery cycles: \(cycle), battery health: \(health), SSD wear: \(ssdWear)%.", language: language)
        case "normal_use":
            return Presentation.text("属于正常使用机器，电池循环 \(cycle) 次，电池健康 \(health)，SSD 寿命消耗 \(ssdWear)% 。", "This looks like a normally used machine. Battery cycles: \(cycle), battery health: \(health), SSD wear: \(ssdWear)%.", language: language)
        case "heavy_use":
            return Presentation.text("使用痕迹较重，电池循环 \(cycle) 次，建议重点复查电池和温控。", "This looks more heavily used, with \(cycle) battery cycles. Battery and thermal checks are recommended.", language: language)
        default:
            return Presentation.text("当前无法完整判断使用强度。", "The usage level cannot be fully determined from current data.", language: language)
        }
    }

    private static func describeAbnormalIssues(report: ASTPlusReport, hardware: [String: String], storage: [String: String], logs: [String: String], language: OutputLanguage) -> String {
        var parts: [String] = []

        if report.classification.lockState == "activation_lock" || report.classification.lockState == "both" {
            parts.append(Presentation.text("检测到 Activation Lock 启用", "Activation Lock is enabled", language: language))
        }
        if let unsafe = storage["unsafe_shutdowns"], unsafe != "0", unsafe != "unknown" {
            parts.append(Presentation.text("SSD 异常断电记录 \(unsafe) 次", "SSD unsafe shutdown count is \(unsafe)", language: language))
        }
        if let panic = logs["panic_count"], panic != "0", panic != "unknown" {
            parts.append(Presentation.text("最近 7 天 panic 相关报告 \(panic) 个", "There are \(panic) panic-related reports in the last 7 days", language: language))
        }
        if let gpu = logs["gpu_keyword_count"], gpu != "0", gpu != "unknown" {
            parts.append(Presentation.text("最近日志里 GPU 异常线索 \(gpu) 个", "Recent logs contain \(gpu) GPU abnormal signals", language: language))
        }

        if parts.isEmpty {
            return Presentation.text("当前未看到明确异常问题。", "No explicit abnormal issue is currently visible.", language: language)
        }
        return parts.joined(separator: Presentation.text("；", "; ", language: language))
    }

    private static func isPortableMachine(report: ASTPlusReport) -> Bool {
        report.machineName.lowercased().contains("macbook")
    }

    private static func describeOtherRisks(report: ASTPlusReport, language: OutputLanguage) -> String {
        if report.overallStatus == "WARN" || report.overallStatus == "FAIL" {
            return Presentation.text("来源和维修历史无法仅靠软件结果 100% 确认；若用于交易，建议结合人工检查、Apple Diagnostics 和 Apple Genius Bar 复核。", "Source and repair history cannot be 100% confirmed from software results alone; for transactions, combine this with manual checks, Apple Diagnostics, and Apple Genius Bar verification.", language: language)
        }
        return Presentation.text("当前没有明显高风险，但软件检测仍不能替代人工检查和官方复核。", "There is no obvious high-risk signal currently, but software checks still do not replace manual inspection and official verification.", language: language)
    }

    private static func statusBadge(_ status: String, language: OutputLanguage) -> String {
        let color: String
        switch status {
        case "PASS":
            color = "green"
        case "WARN":
            color = "goldenrod"
        case "FAIL":
            color = "red"
        default:
            color = "gray"
        }
        return "<span style=\"color:\(color)\"><strong>\(Presentation.statusLabel(status, language: language))</strong></span>"
    }

    private static func highlights(for key: String, report: ModuleReport, language: OutputLanguage) -> [String] {
        switch key {
        case "hardware":
            return formattedHighlights(
                keys: ["machine_model", "chip_type", "physical_memory", "serial_number", "activation_lock_status"],
                report: report,
                language: language
            )
        case "battery":
            return formattedHighlights(
                keys: ["cycle_count", "max_capacity_percent", "design_cycle_count", "design_capacity_mah", "nominal_charge_capacity_mah", "temperature_celsius", "is_charging"],
                report: report,
                language: language
            )
        case "storage":
            return formattedHighlights(
                keys: ["smart_status", "percentage_used", "unsafe_shutdowns", "media_errors", "error_log_entries", "temperature_celsius", "nvme_controller", "trim_support"],
                report: report,
                language: language
            )
        case "logs":
            return formattedHighlights(
                keys: ["panic_count", "io_error_count", "gpu_keyword_count", "previous_shutdown_cause_count", "nvme_keyword_count", "structured_log_event_count"],
                report: report,
                language: language
            )
        case "stress":
            return formattedHighlights(
                keys: ["duration_seconds", "iterations", "worker_count", "memory_bytes_tested", "memory_checksum", "memory_pass"],
                report: report,
                language: language
            )
        case "postStress":
            return formattedHighlights(
                keys: ["battery_temp_delta", "storage_temp_delta", "unsafe_shutdowns_delta"],
                report: report,
                language: language
            )
        default:
            return []
        }
    }

    private static func explanations(for key: String, language: OutputLanguage) -> [String] {
        switch key {
        case "battery":
            return [
                Presentation.text("`cycle_count` 是电池循环次数，通常越低越接近新机状态。", "`cycle_count` is the battery cycle count. Lower is usually closer to a new-machine state.", language: language),
                Presentation.text("`max_capacity_percent` 是当前满充容量相对于设计容量的比例，是二手 Mac 最关键的电池指标之一。", "`max_capacity_percent` is the current full-charge capacity relative to design capacity, one of the most important battery indicators for used Macs.", language: language),
                Presentation.text("`temperature_celsius` 用于观察当前是否存在异常发热，需结合充电状态和压测结果一起看。", "`temperature_celsius` helps identify abnormal heating and should be reviewed together with charging state and stress results.", language: language)
            ]
        case "storage":
            return [
                Presentation.text("`unsafe_shutdowns` 是 SSD 记录到的异常断电次数，数量偏高通常意味着这台机器经历过非正常断电或强制关机。", "`unsafe_shutdowns` is the SSD unsafe shutdown counter. Elevated values usually mean abnormal power loss or forced shutdowns happened before.", language: language),
                Presentation.text("`percentage_used` 表示 SSD 寿命消耗百分比，越低越接近新盘。", "`percentage_used` is the SSD wear indicator. Lower means closer to a newer drive.", language: language),
                Presentation.text("`media_errors` 和 `error_log_entries` 如果大于 0，应优先视为强风险信号。", "`media_errors` and `error_log_entries` should be treated as strong risk signals if greater than 0.", language: language)
            ]
        case "logs":
            return [
                Presentation.text("`panic_count` 表示近期内核崩溃报告数量。", "`panic_count` is the number of recent kernel panic reports.", language: language),
                Presentation.text("`gpu_keyword_count` 与 `nvme_keyword_count` 用于快速识别 GPU 和存储相关异常线索。", "`gpu_keyword_count` and `nvme_keyword_count` help quickly surface GPU and storage-related abnormal signals.", language: language),
                Presentation.text("`previous_shutdown_cause_count` 可以帮助识别异常关机历史。", "`previous_shutdown_cause_count` helps identify abnormal shutdown history.", language: language)
            ]
        case "stress":
            return [
                Presentation.text("`iterations` 是本次 CPU 压测完成的计算迭代数，用来确认压测是否实际执行。", "`iterations` is the CPU stress iteration count and confirms that the stress run really executed.", language: language),
                Presentation.text("`memory_bytes_tested` 与 `memory_pass` 是基础内存分配与校验结果，表示压测不只跑 CPU，也做了轻量内存探针。", "`memory_bytes_tested` and `memory_pass` are the basic memory allocation/check results, meaning the stress pass includes a lightweight memory probe as well.", language: language)
            ]
        case "postStress":
            return [
                Presentation.text("这一节用于对比压测前后关键指标，重点看温度增幅和 `unsafe_shutdowns` 是否增长。", "This section compares key indicators before and after stress, focusing on temperature deltas and whether `unsafe_shutdowns` increased.", language: language)
            ]
        default:
            return []
        }
    }

    private static func formattedHighlights(keys: [String], report: ModuleReport, language: OutputLanguage) -> [String] {
        keys.compactMap { key in
            guard let value = report.rawValues[key] else { return nil }
            return "`\(localizedKey(key, language: language))`: \(value)"
        }
    }

    private static func valueWithUnit(_ value: String?, unit: String) -> String {
        guard let value, value != "unknown" else { return "unknown" }
        if unit.isEmpty || value.hasSuffix("%") || value.hasSuffix("C") || value.hasSuffix("°C") {
            return value
        }
        return "\(value)\(unit)"
    }

    private static func localizedKey(_ key: String, language: OutputLanguage) -> String {
        switch key {
        case "machine_model": return Presentation.text("机型标识", "Model Identifier", language: language)
        case "chip_type": return Presentation.text("芯片", "Chip", language: language)
        case "physical_memory": return Presentation.text("内存", "Memory", language: language)
        case "serial_number": return Presentation.text("序列号", "Serial Number", language: language)
        case "activation_lock_status": return Presentation.text("激活锁状态", "Activation Lock", language: language)
        case "cycle_count": return Presentation.text("电池循环次数", "Battery Cycle Count", language: language)
        case "max_capacity_percent": return Presentation.text("电池健康容量", "Battery Health Capacity", language: language)
        case "design_cycle_count": return Presentation.text("设计循环上限", "Design Cycle Limit", language: language)
        case "design_capacity_mah": return Presentation.text("设计容量(mAh)", "Design Capacity (mAh)", language: language)
        case "nominal_charge_capacity_mah": return Presentation.text("当前满充容量(mAh)", "Current Full Charge Capacity (mAh)", language: language)
        case "temperature_celsius": return Presentation.text("温度(摄氏度)", "Temperature (C)", language: language)
        case "is_charging": return Presentation.text("是否充电", "Charging", language: language)
        case "smart_status": return Presentation.text("SMART 状态", "SMART Status", language: language)
        case "percentage_used": return Presentation.text("SSD 寿命消耗", "SSD Percentage Used", language: language)
        case "unsafe_shutdowns": return Presentation.text("异常断电次数", "Unsafe Shutdowns", language: language)
        case "media_errors": return Presentation.text("介质错误", "Media Errors", language: language)
        case "error_log_entries": return Presentation.text("错误日志条目", "Error Log Entries", language: language)
        case "nvme_controller": return Presentation.text("NVMe 控制器", "NVMe Controller", language: language)
        case "trim_support": return Presentation.text("TRIM 支持", "TRIM Support", language: language)
        case "panic_count": return Presentation.text("panic 数量", "Panic Count", language: language)
        case "io_error_count": return Presentation.text("I/O 错误数量", "I/O Error Count", language: language)
        case "gpu_keyword_count": return Presentation.text("GPU 异常线索", "GPU Signal Count", language: language)
        case "previous_shutdown_cause_count": return Presentation.text("异常关机记录", "Previous Shutdown Cause Count", language: language)
        case "nvme_keyword_count": return Presentation.text("NVMe 异常线索", "NVMe Signal Count", language: language)
        case "structured_log_event_count": return Presentation.text("结构化日志事件数", "Structured Log Events", language: language)
        case "duration_seconds": return Presentation.text("压测时长(秒)", "Stress Duration (s)", language: language)
        case "iterations": return Presentation.text("CPU 迭代数", "CPU Iterations", language: language)
        case "worker_count": return Presentation.text("工作线程数", "Worker Count", language: language)
        case "memory_bytes_tested": return Presentation.text("内存探针字节数", "Memory Probe Bytes", language: language)
        case "memory_checksum": return Presentation.text("内存校验值", "Memory Checksum", language: language)
        case "memory_pass": return Presentation.text("内存探针是否通过", "Memory Probe Pass", language: language)
        case "battery_temp_delta": return Presentation.text("电池温度变化", "Battery Temp Delta", language: language)
        case "storage_temp_delta": return Presentation.text("存储温度变化", "Storage Temp Delta", language: language)
        case "unsafe_shutdowns_delta": return Presentation.text("异常断电增量", "Unsafe Shutdown Delta", language: language)
        default: return key
        }
    }
}

private struct InspectionItem {
    let englishName: String
    let actualData: String
    let chineseMeaning: String
}

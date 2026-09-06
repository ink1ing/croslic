import Foundation

struct ModuleReport: Encodable {
    let status: String
    let reason: String
    let rawValues: [String: String]
    let thresholds: [String: String]
}

struct ASTPlusReport: Encodable {
    let generatedAt: String
    let machineName: String
    let mode: String
    let overallStatus: String
    let summary: [String]
    let classification: ClassificationReport
    let hardware: ModuleReport
    let battery: ModuleReport
    let storage: ModuleReport
    let logs: ModuleReport
    let peripherals: ModuleReport
    let stress: ModuleReport
    let deepMetrics: ModuleReport
    let postStress: ModuleReport
    let artifacts: [CollectedCommand]
}

struct ClassificationReport: Encodable {
    let originType: String
    let usageState: String
    let hardwareState: String
    let lockState: String
    let confidence: [String: String]
    let evidence: [String]
    let note: String
}

struct Evaluator {
    let snapshot: Snapshot
    let postStressSnapshot: PostStressSnapshot?
    let stressSummary: StressSummary

    func buildReport() -> ASTPlusReport {
        let hardwareReport = evaluateHardware()
        let batteryReport = evaluateBattery()
        let storageReport = evaluateStorage()
        let logReport = evaluateLogs()
        let peripheralReport = evaluatePeripherals()
        let stressReport = evaluateStress()
        let deepMetricsReport = evaluateDeepMetrics()
        let postStressReport = evaluatePostStress()
        let classificationReport = evaluateClassification()

        let statuses = [
            hardwareReport.status,
            batteryReport.status,
            storageReport.status,
            logReport.status,
            peripheralReport.status,
            stressReport.status,
            deepMetricsReport.status,
            postStressReport.status
        ]

        let overall = overallStatus(for: statuses)
        let summary = buildSummary(
            hardware: hardwareReport,
            battery: batteryReport,
            storage: storageReport,
            logs: logReport,
            peripherals: peripheralReport,
            stress: stressReport,
            deepMetrics: deepMetricsReport,
            postStress: postStressReport
        )

        return ASTPlusReport(
            generatedAt: snapshot.timestamp,
            machineName: snapshot.hardware["machine_name"] ?? "Unknown Mac",
            mode: snapshot.deepMode ? "deep" : "standard",
            overallStatus: overall,
            summary: summary,
            classification: classificationReport,
            hardware: hardwareReport,
            battery: batteryReport,
            storage: storageReport,
            logs: logReport,
            peripherals: peripheralReport,
            stress: stressReport,
            deepMetrics: deepMetricsReport,
            postStress: postStressReport,
            artifacts: snapshot.commands
        )
    }

    private func evaluateHardware() -> ModuleReport {
        let serial = snapshot.hardware["serial_number"] ?? ""
        let chip = snapshot.hardware["chip_type"] ?? "Unknown"
        let model = snapshot.hardware["machine_model"] ?? "Unknown"
        let modelNumber = snapshot.hardware["model_number"] ?? "Unknown"
        let activation = snapshot.hardware["activation_lock_status"] ?? "unknown"

        let status: String
        let reason: String
        if serial.count < 8 || model.isEmpty {
            status = "FAIL"
            reason = "关键机器身份字段缺失，无法建立可信基线。"
        } else if activation == "activation_lock_enabled" {
            status = "WARN"
            reason = "检测到 Activation Lock 处于启用状态，交易前必须确认已退出所有者账户。"
        } else {
            status = "PASS"
            reason = "机器身份字段完整，高层硬件信息可用于后续交叉校验。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "machine_name": snapshot.hardware["machine_name"] ?? "unknown",
                "machine_model": model,
                "model_number": modelNumber,
                "chip_type": chip,
                "physical_memory": snapshot.hardware["physical_memory"] ?? "unknown",
                "serial_number": serial,
                "activation_lock_status": activation
            ],
            thresholds: [
                "serial_number": "不能为空且长度应合理",
                "hardware_baseline": "型号、芯片、内存、固件字段应完整"
            ]
        )
    }

    private func evaluateBattery() -> ModuleReport {
        if !isPortableMachine() {
            return ModuleReport(
                status: "UNKNOWN",
                reason: "当前机型无内置电池，此项不适用。",
                rawValues: [
                    "battery_applicable": "false"
                ],
                thresholds: [
                    "note": "桌面机型不适用电池循环与容量判断"
                ]
            )
        }

        let cycle = snapshot.battery.cycleCount
        let capacity = snapshot.battery.maxCapacityPercent
        let temperature = snapshot.battery.temperatureCelsius

        let status: String
        let reason: String

        if let condition = snapshot.battery.condition?.lowercased(), condition.contains("service") {
            status = "FAIL"
            reason = "系统已提示电池需要维修。"
        } else if let capacity, capacity < 85 {
            status = "WARN"
            reason = "电池健康容量低于 85%，属于需要重点关注的范围。"
        } else if let cycle, cycle > 600 {
            status = "WARN"
            reason = "循环次数较高，建议结合容量与温度继续复检。"
        } else if let temperature, temperature > 40 {
            status = "WARN"
            reason = "当前电池温度偏高，需结合负载与充电状态观察。"
        } else if cycle != nil || capacity != nil {
            status = "PASS"
            reason = "电池关键字段可读取，当前未触发高风险阈值。"
        } else {
            status = "UNKNOWN"
            reason = "未能完整读取电池关键字段。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "cycle_count": valueString(cycle),
                "condition": snapshot.battery.condition ?? "unknown",
                "max_capacity_percent": percentString(snapshot.battery.maxCapacityPercent),
                "current_charge_percent": percentString(snapshot.battery.currentChargePercent),
                "temperature_celsius": decimalString(temperature),
                "is_charging": boolString(snapshot.battery.isCharging),
                "design_cycle_count": valueString(snapshot.battery.designCycleCount),
                "design_capacity_mah": valueString(snapshot.battery.designCapacityMah),
                "nominal_charge_capacity_mah": valueString(snapshot.battery.nominalChargeCapacityMah),
                "battery_serial": snapshot.battery.batterySerial ?? "unknown"
            ],
            thresholds: [
                "excellent": "cycle < 100 && capacity > 95%",
                "good": "cycle < 300 && capacity > 90%",
                "acceptable": "cycle < 600 && capacity > 85%",
                "warning": "cycle > 600 || capacity < 85%"
            ]
        )
    }

    private func evaluateStorage() -> ModuleReport {
        let smart = snapshot.storage.smartStatus?.lowercased()

        let status: String
        let reason: String
        if smart == "failing" {
            status = "FAIL"
            reason = "磁盘 SMART 已报告失败。"
        } else if snapshot.nvme.smartStatus?.lowercased() == "failing" {
            status = "FAIL"
            reason = "NVMe 控制器已报告 SMART 失败。"
        } else if (snapshot.storage.mediaErrors ?? 0) > 0 {
            status = "FAIL"
            reason = "检测到存储介质完整性错误，属于硬性红线。"
        } else if (snapshot.storage.errorLogEntries ?? 0) > 0 || (snapshot.storage.unsafeShutdowns ?? 0) > 20 {
            status = "WARN"
            reason = "存储错误日志或异常断电计数偏高，建议结合压测与原始 SMART 数据复核。"
        } else if smart == "verified" || smart == "not supported" || smart == nil {
            if snapshot.storage.physicalStoreIdentifier == nil && snapshot.storage.deviceIdentifier == nil {
                status = "UNKNOWN"
                reason = "未能读取到磁盘设备信息。"
            } else {
                status = "PASS"
                reason = "已获取物理盘基础信息和 SMART 关键指标，当前未发现明确失败信号。"
            }
        } else {
            status = "WARN"
            reason = "SMART 状态非标准结果，建议进一步复检。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "device_identifier": snapshot.storage.deviceIdentifier ?? "unknown",
                "physical_store_identifier": snapshot.storage.physicalStoreIdentifier ?? "unknown",
                "media_name": snapshot.storage.mediaName ?? snapshot.nvme.deviceModel ?? "unknown",
                "total_size_bytes": valueString(snapshot.storage.totalSizeBytes),
                "solid_state": boolString(snapshot.storage.solidState),
                "smart_status": snapshot.storage.smartStatus ?? snapshot.nvme.smartStatus ?? "unknown",
                "filesystem": snapshot.storage.fileSystemName ?? "unknown",
                "media_errors": valueString(snapshot.storage.mediaErrors),
                "error_log_entries": valueString(snapshot.storage.errorLogEntries),
                "unsafe_shutdowns": valueString(snapshot.storage.unsafeShutdowns),
                "percentage_used": valueString(snapshot.storage.percentageUsed),
                "temperature_celsius": decimalString(snapshot.storage.temperatureCelsius),
                "nvme_controller": snapshot.nvme.controllerName ?? "unknown",
                "nvme_serial": snapshot.nvme.serial ?? "unknown",
                "trim_support": snapshot.nvme.trimSupport ?? "unknown"
            ],
            thresholds: [
                "critical": "SMART failing 或 media_errors > 0 => FAIL",
                "warning": "error_log_entries > 0 或 unsafe_shutdowns > 20 => WARN",
                "baseline": "应能读取物理盘标识、容量、SMART 与关键 NVMe 指标"
            ]
        )
    }

    private func evaluateLogs() -> ModuleReport {
        let logCounts = snapshot.logs

        let status: String
        let reason: String
        if logCounts.panicCount > 0 || logCounts.ioErrorCount > 0 || logCounts.previousShutdownCauseCount > 0 {
            status = "WARN"
            reason = "最近 7 天的 panic、I/O error 或异常关机日志中存在异常线索，需要人工复核原始证据。"
        } else if logCounts.gpuResetCount > 3 || logCounts.nvmeErrorCount > 0 {
            status = "WARN"
            reason = "最近 7 天的结构化日志中存在 GPU 或 NVMe 相关异常线索，需结合压测进一步确认。"
        } else {
            status = "PASS"
            reason = "最近 7 天的 panic 报告、结构化日志和电源日志未见明显异常。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "panic_count": valueString(logCounts.panicCount),
                "io_error_count": valueString(logCounts.ioErrorCount),
                "gpu_keyword_count": valueString(logCounts.gpuResetCount),
                "shutdown_event_count": valueString(logCounts.shutdownEventCount),
                "previous_shutdown_cause_count": valueString(logCounts.previousShutdownCauseCount),
                "nvme_keyword_count": valueString(logCounts.nvmeErrorCount),
                "structured_log_event_count": valueString(logCounts.structuredLogEventCount)
            ],
            thresholds: [
                "panic": "> 0 => WARN",
                "io_error": "> 0 => WARN",
                "previous_shutdown_cause": "> 0 => WARN",
                "gpu_events": "> 3 => WARN",
                "nvme_events": "> 0 => WARN"
            ]
        )
    }

    private func evaluatePeripherals() -> ModuleReport {
        let peripheral = snapshot.peripherals

        let missing = [
            peripheral.wifiAvailable ? nil : "Wi-Fi",
            peripheral.bluetoothAvailable ? nil : "Bluetooth",
            peripheral.cameraAvailable ? nil : "Camera",
            peripheral.audioDeviceCount > 0 ? nil : "Audio"
        ].compactMap { $0 }

        let status: String
        let reason: String
        if missing.isEmpty {
            status = "PASS"
            reason = "基础外设已被系统识别，仍建议做人工交互复测。"
        } else {
            status = "WARN"
            reason = "以下模块未在系统枚举中明确出现：\(missing.joined(separator: ", "))。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "display_count": valueString(peripheral.displayCount),
                "wifi_available": boolString(peripheral.wifiAvailable),
                "bluetooth_available": boolString(peripheral.bluetoothAvailable),
                "camera_available": boolString(peripheral.cameraAvailable),
                "audio_device_count": valueString(peripheral.audioDeviceCount)
            ],
            thresholds: [
                "baseline": "显示、Wi-Fi、蓝牙、摄像头、音频应可被系统识别",
                "note": "可识别 != 完全可用，仍需人工检查"
            ]
        )
    }

    private func evaluateStress() -> ModuleReport {
        let status: String
        let reason: String

        if stressSummary.completed && stressSummary.iterations > 0 {
            status = "PASS"
            reason = "CPU 标准压测已完成，未出现运行时中断。"
        } else if stressSummary.skipped {
            status = "UNKNOWN"
            reason = "本次运行显式跳过了 CPU 压测。"
        } else {
            status = "FAIL"
            reason = "CPU 压测未正常完成。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "duration_seconds": valueString(stressSummary.durationSeconds),
                "worker_count": valueString(stressSummary.workerCount),
                "iterations": valueString(stressSummary.iterations),
                "elapsed_seconds": decimalString(stressSummary.elapsedSeconds),
                "memory_bytes_tested": valueString(stressSummary.memoryBytesTested),
                "memory_checksum": valueString(stressSummary.memoryChecksum),
                "memory_pass": boolString(stressSummary.memoryPass)
            ],
            thresholds: [
                "completion": "压测应完整执行且不中断",
                "scope": "当前包含 CPU 计算压测和基础内存分配校验",
                "memory": "memory_pass 应为 true"
            ]
        )
    }

    private func evaluateDeepMetrics() -> ModuleReport {
        if !snapshot.deepMode {
            return ModuleReport(
                status: "UNKNOWN",
                reason: "本次未启用深度模式。",
                rawValues: ["powermetrics_available": "false"],
                thresholds: ["deep_mode": "启用 --deep 后可尝试采集 powermetrics"]
            )
        }

        if snapshot.deepMetrics.available {
            return ModuleReport(
                status: "PASS",
                reason: snapshot.deepMetrics.note ?? "深度模式采集成功。",
                rawValues: ["powermetrics_available": "true"],
                thresholds: ["powermetrics": "应能无交互执行 sudo -n powermetrics"]
            )
        }

        return ModuleReport(
            status: "WARN",
            reason: snapshot.deepMetrics.note ?? "深度模式采集失败。",
            rawValues: ["powermetrics_available": "false"],
            thresholds: ["powermetrics": "若需要温控深采样，应配置免交互 sudo 或手动补采样"]
        )
    }

    private func evaluatePostStress() -> ModuleReport {
        guard let postStressSnapshot else {
            return ModuleReport(
                status: "UNKNOWN",
                reason: stressSummary.skipped ? "本次跳过压测，因此没有前后对比采样。" : "压测后采样不可用。",
                rawValues: [:],
                thresholds: ["post_stress": "压测完成后应补采样电池与存储关键指标"]
            )
        }

        let batteryDelta = deltaString(before: snapshot.battery.temperatureCelsius, after: postStressSnapshot.battery.temperatureCelsius, unit: "C")
        let storageDelta = deltaString(before: snapshot.storage.temperatureCelsius, after: postStressSnapshot.storage.temperatureCelsius, unit: "C")
        let unsafeShutdownDelta = deltaIntString(before: snapshot.storage.unsafeShutdowns, after: postStressSnapshot.storage.unsafeShutdowns)

        let status: String
        let reason: String
        if (unsafeShutdownDelta.delta ?? 0) > 0 {
            status = "WARN"
            reason = "压测后异常断电计数发生变化，需复核存储与供电稳定性。"
        } else {
            status = "PASS"
            reason = "已完成压测前后关键指标采样，未见异常断电计数增长。"
        }

        return ModuleReport(
            status: status,
            reason: reason,
            rawValues: [
                "battery_temp_before_c": decimalString(snapshot.battery.temperatureCelsius),
                "battery_temp_after_c": decimalString(postStressSnapshot.battery.temperatureCelsius),
                "battery_temp_delta": batteryDelta.text,
                "storage_temp_before_c": decimalString(snapshot.storage.temperatureCelsius),
                "storage_temp_after_c": decimalString(postStressSnapshot.storage.temperatureCelsius),
                "storage_temp_delta": storageDelta.text,
                "unsafe_shutdowns_before": valueString(snapshot.storage.unsafeShutdowns),
                "unsafe_shutdowns_after": valueString(postStressSnapshot.storage.unsafeShutdowns),
                "unsafe_shutdowns_delta": unsafeShutdownDelta.text
            ],
            thresholds: [
                "unsafe_shutdowns": "压测前后不应增长",
                "temperature": "温度升高允许存在，但应结合节流和错误日志分析"
            ]
        )
    }

    private func evaluateClassification() -> ClassificationReport {
        let modelNumber = snapshot.hardware["model_number"] ?? ""
        let activationEnabled = snapshot.hardware["activation_lock_status"] == "activation_lock_enabled"
        let mdmEnrolled = snapshot.enrollment.mdmEnrolled == true
        let depEnrolled = snapshot.enrollment.depEnrolled == true

        let originType: String
        let originConfidence: String
        if let prefix = modelNumber.first {
            switch prefix {
            case "M":
                originType = "retail"
                originConfidence = "medium"
            case "F":
                originType = "refurbished"
                originConfidence = "medium"
            case "N":
                originType = "service_replacement"
                originConfidence = "medium"
            case "P":
                originType = "configured_to_order"
                originConfidence = "medium"
            default:
                originType = depEnrolled || mdmEnrolled ? "enterprise" : "unknown"
                originConfidence = depEnrolled || mdmEnrolled ? "medium" : "low"
            }
        } else {
            originType = depEnrolled || mdmEnrolled ? "enterprise" : "unknown"
            originConfidence = depEnrolled || mdmEnrolled ? "medium" : "low"
        }

        let usageState: String
        let usageConfidence: String
        if isPortableMachine(), let cycle = snapshot.battery.cycleCount {
            switch cycle {
            case ..<5:
                usageState = "unused"
            case ..<50:
                usageState = "light_use"
            case ..<500:
                usageState = "normal_use"
            default:
                usageState = "heavy_use"
            }
            usageConfidence = "high"
        } else if let used = snapshot.storage.percentageUsed {
            switch used {
            case ..<1:
                usageState = "unused"
            case ..<5:
                usageState = "light_use"
            case ..<20:
                usageState = "normal_use"
            default:
                usageState = "heavy_use"
            }
            usageConfidence = "medium"
        } else {
            usageState = "unknown"
            usageConfidence = "low"
        }

        let hardwareState: String
        let hardwareConfidence: String
        if snapshot.storage.mediaErrors ?? 0 > 0 || snapshot.storage.smartStatus?.lowercased() == "failing" {
            hardwareState = "faulty"
            hardwareConfidence = "high"
        } else if snapshot.battery.condition?.lowercased().contains("service") == true || snapshot.logs.panicCount > 0 || snapshot.logs.ioErrorCount > 0 {
            hardwareState = "signal_present"
            hardwareConfidence = "medium"
        } else if snapshot.storage.deviceIdentifier != nil || snapshot.battery.cycleCount != nil || !isPortableMachine() {
            hardwareState = "no_clear_fault_signal"
            hardwareConfidence = "medium"
        } else {
            hardwareState = "unknown"
            hardwareConfidence = "low"
        }

        let lockState: String
        let lockConfidence: String
        switch (activationEnabled, mdmEnrolled || depEnrolled) {
        case (true, true):
            lockState = "both"
            lockConfidence = "high"
        case (true, false):
            lockState = "activation_lock"
            lockConfidence = "high"
        case (false, true):
            lockState = "mdm_lock"
            lockConfidence = "high"
        case (false, false):
            lockState = "none"
            lockConfidence = "medium"
        }

        var evidence: [String] = []
        if !modelNumber.isEmpty {
            evidence.append("model_number=\(modelNumber)")
        }
        if let cycle = snapshot.battery.cycleCount {
            evidence.append("battery_cycle=\(cycle)")
        }
        if let capacity = snapshot.battery.maxCapacityPercent {
            evidence.append("battery_health=\(String(format: "%.1f", capacity))")
        }
        if let used = snapshot.storage.percentageUsed {
            evidence.append("ssd_percentage_used=\(used)")
        }
        if let shutdowns = snapshot.storage.unsafeShutdowns {
            evidence.append("unsafe_shutdowns=\(shutdowns)")
        }
        evidence.append("activation_lock=\(activationEnabled)")
        evidence.append("mdm_enrolled=\(mdmEnrolled)")
        evidence.append("dep_enrolled=\(depEnrolled)")

        return ClassificationReport(
            originType: originType,
            usageState: usageState,
            hardwareState: hardwareState,
            lockState: lockState,
            confidence: [
                "origin_type": originConfidence,
                "usage_state": usageConfidence,
                "hardware_state": hardwareConfidence,
                "lock_state": lockConfidence
            ],
            evidence: evidence,
            note: "来源和维修类型无法仅靠当前软件结果 100% 确认；若交易敏感，建议到 Apple Genius Bar 或官方渠道进一步核验。"
        )
    }

    private func buildSummary(
        hardware: ModuleReport,
        battery: ModuleReport,
        storage: ModuleReport,
        logs: ModuleReport,
        peripherals: ModuleReport,
        stress: ModuleReport,
        deepMetrics: ModuleReport,
        postStress: ModuleReport
    ) -> [String] {
        [
            "硬件基线：\(hardware.status) - \(hardware.reason)",
            "电池：\(battery.status) - \(battery.reason)",
            "存储：\(storage.status) - \(storage.reason)",
            "日志：\(logs.status) - \(logs.reason)",
            "外设：\(peripherals.status) - \(peripherals.reason)",
            "压测：\(stress.status) - \(stress.reason)",
            "深度采样：\(deepMetrics.status) - \(deepMetrics.reason)",
            "压测前后对比：\(postStress.status) - \(postStress.reason)"
        ]
    }

    private func isPortableMachine() -> Bool {
        let machineName = snapshot.hardware["machine_name"]?.lowercased() ?? ""
        let model = snapshot.hardware["machine_model"]?.lowercased() ?? ""
        return machineName.contains("macbook") || model.contains("book")
    }

    private func overallStatus(for statuses: [String]) -> String {
        if statuses.contains("FAIL") {
            return "FAIL"
        }
        if statuses.contains("WARN") {
            return "WARN"
        }
        if statuses.allSatisfy({ $0 == "PASS" }) {
            return "PASS"
        }
        return "UNKNOWN"
    }
}

private func valueString<T: CustomStringConvertible>(_ value: T?) -> String {
    value?.description ?? "unknown"
}

private func decimalString(_ value: Double?) -> String {
    guard let value else { return "unknown" }
    return String(format: "%.2f", value)
}

private func percentString(_ value: Double?) -> String {
    guard let value else { return "unknown" }
    return String(format: "%.1f%%", value)
}

private func boolString(_ value: Bool?) -> String {
    guard let value else { return "unknown" }
    return value ? "true" : "false"
}

private func deltaString(before: Double?, after: Double?, unit: String) -> (delta: Double?, text: String) {
    guard let before, let after else {
        return (nil, "unknown")
    }
    let delta = after - before
    return (delta, String(format: "%+.2f%@", delta, unit))
}

private func deltaIntString(before: Int?, after: Int?) -> (delta: Int?, text: String) {
    guard let before, let after else {
        return (nil, "unknown")
    }
    let delta = after - before
    return (delta, delta >= 0 ? "+\(delta)" : "\(delta)")
}

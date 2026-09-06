import Foundation

struct CollectedCommand: Encodable {
    let name: String
    let command: [String]
    let exitCode: Int32
    let outputFile: String
    let stderrFile: String?
}

struct Snapshot: Encodable {
    let timestamp: String
    let deepMode: Bool
    let commands: [CollectedCommand]
    let hardware: [String: String]
    let software: [String: String]
    let battery: BatterySnapshot
    let storage: StorageSnapshot
    let nvme: NVMESnapshot
    let logs: LogSnapshot
    let peripherals: PeripheralSnapshot
    let enrollment: EnrollmentSnapshot
    let deepMetrics: DeepMetricsSnapshot
}

struct BatterySnapshot: Encodable {
    let cycleCount: Int?
    let designCycleCount: Int?
    let condition: String?
    let maxCapacityPercent: Double?
    let currentChargePercent: Double?
    let isCharging: Bool?
    let temperatureCelsius: Double?
    let powerSource: String?
    let designCapacityMah: Int?
    let nominalChargeCapacityMah: Int?
    let batterySerial: String?
}

struct StorageSnapshot: Encodable {
    let deviceIdentifier: String?
    let physicalStoreIdentifier: String?
    let mediaName: String?
    let totalSizeBytes: Int64?
    let solidState: Bool?
    let smartStatus: String?
    let fileSystemName: String?
    let volumeName: String?
    let percentageUsed: Int?
    let unsafeShutdowns: Int?
    let mediaErrors: Int?
    let errorLogEntries: Int?
    let temperatureCelsius: Double?
}

struct NVMESnapshot: Encodable {
    let controllerName: String?
    let deviceModel: String?
    let bsdName: String?
    let serial: String?
    let sizeBytes: Int64?
    let smartStatus: String?
    let trimSupport: String?
}

struct LogSnapshot: Encodable {
    let panicCount: Int
    let ioErrorCount: Int
    let gpuResetCount: Int
    let shutdownEventCount: Int
    let previousShutdownCauseCount: Int
    let nvmeErrorCount: Int
    let structuredLogEventCount: Int
}

struct PeripheralSnapshot: Encodable {
    let displayCount: Int
    let wifiAvailable: Bool
    let bluetoothAvailable: Bool
    let cameraAvailable: Bool
    let audioDeviceCount: Int
}

struct EnrollmentSnapshot: Encodable {
    let depEnrolled: Bool?
    let mdmEnrolled: Bool?
}

struct DeepMetricsSnapshot: Encodable {
    let available: Bool
    let note: String?
}

struct PostStressSnapshot: Encodable {
    let battery: BatterySnapshot
    let storage: StorageSnapshot
}

struct SystemCollector {
    let runner: CommandRunner
    let artifactsDirectory: URL
    let deepMode: Bool
    let logWindow: String
    let language: OutputLanguage

    func collect() throws -> Snapshot {
        let specs: [(String, [String])] = [
            ("hardware", ["/usr/sbin/system_profiler", "SPHardwareDataType", "-json"]),
            ("software", ["/usr/sbin/system_profiler", "SPSoftwareDataType", "-json"]),
            ("power", ["/usr/sbin/system_profiler", "SPPowerDataType", "-json"]),
            ("storage_root", ["/usr/sbin/diskutil", "info", "-plist", "/"]),
            ("nvme", ["/usr/sbin/system_profiler", "SPNVMeDataType", "-json"]),
            ("displays", ["/usr/sbin/system_profiler", "SPDisplaysDataType", "-json"]),
            ("wifi", ["/usr/sbin/system_profiler", "SPAirPortDataType", "-json"]),
            ("bluetooth", ["/usr/sbin/system_profiler", "SPBluetoothDataType", "-json"]),
            ("camera", ["/usr/sbin/system_profiler", "SPCameraDataType", "-json"]),
            ("audio", ["/usr/sbin/system_profiler", "SPAudioDataType", "-json"]),
            ("battery_ioreg", ["/usr/sbin/ioreg", "-r", "-c", "AppleSmartBattery", "-l"]),
            ("pmset_batt", ["/usr/bin/pmset", "-g", "batt"]),
            ("profiles_enrollment", ["/usr/bin/profiles", "status", "-type", "enrollment"]),
            ("pmset_therm", ["/usr/bin/pmset", "-g", "therm"]),
            ("pmset_log", ["/bin/sh", "-c", "/usr/bin/pmset -g log | tail -n 200"]),
            ("log_show", ["/bin/sh", "-c", "/usr/bin/log show --last \(logWindow) --style json --predicate '(eventMessage CONTAINS[c] \"Previous shutdown cause\" OR composedMessage CONTAINS[c] \"Previous shutdown cause\" OR eventMessage CONTAINS[c] \"I/O error\" OR composedMessage CONTAINS[c] \"I/O error\" OR eventMessage CONTAINS[c] \"nvme\" OR composedMessage CONTAINS[c] \"nvme\" OR eventMessage CONTAINS[c] \"GPU\" OR composedMessage CONTAINS[c] \"GPU\")' | tail -n 200"]),
            ("panic_reports", ["/usr/bin/find", "/Library/Logs/DiagnosticReports", "\(NSHomeDirectory())/Library/Logs/DiagnosticReports", "-type", "f", "(", "-iname", "*panic*", "-o", "-iname", "*gpu*", "-o", "-iname", "*watchdog*", ")", "-mtime", "-7", "-print"])
        ]

        var outputs: [String: CommandOutput] = [:]
        var commandRecords: [CollectedCommand] = []
        let totalCommandCount = specs.count + 1 + (deepMode ? 1 : 0)
        var commandIndex = 0

        for (name, command) in specs {
            commandIndex += 1
            TerminalProgressRenderer.command(index: commandIndex, total: totalCommandCount, name: name, command: command, language: language)
            let output = try runner.run(command)
            TerminalProgressRenderer.commandFinished(name: name, exitCode: output.exitCode, language: language)
            outputs[name] = output
            commandRecords.append(try persist(output: output, named: name))
        }

        if let physicalStore = parsePhysicalStoreIdentifier(from: outputs["storage_root"]?.standardOutput ?? "") {
            let storageCommand = ["/usr/sbin/diskutil", "info", "-plist", physicalStore]
            commandIndex += 1
            TerminalProgressRenderer.command(index: commandIndex, total: totalCommandCount, name: "storage_physical", command: storageCommand, language: language)
            let output = try runner.run(storageCommand)
            TerminalProgressRenderer.commandFinished(name: "storage_physical", exitCode: output.exitCode, language: language)
            outputs["storage_physical"] = output
            commandRecords.append(try persist(output: output, named: "storage_physical"))
        }

        var deepMetrics = DeepMetricsSnapshot(available: false, note: nil)

        if deepMode {
            let deepCommand = ["/usr/bin/env", "sudo", "-n", "/usr/bin/powermetrics", "--samplers", "smc", "-n", "1"]
            commandIndex += 1
            TerminalProgressRenderer.command(index: commandIndex, total: totalCommandCount, name: "powermetrics", command: deepCommand, language: language)
            let output = try runner.run(deepCommand)
            TerminalProgressRenderer.commandFinished(name: "powermetrics", exitCode: output.exitCode, language: language)
            outputs["powermetrics"] = output
            commandRecords.append(try persist(output: output, named: "powermetrics"))
            deepMetrics = DeepMetricsSnapshot(
                available: output.exitCode == 0,
                note: output.exitCode == 0 ? "powermetrics captured" : "powermetrics 需要免交互 sudo，当前已跳过"
            )
        }

        return Snapshot(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            deepMode: deepMode,
            commands: commandRecords,
            hardware: parseHardware(from: outputs["hardware"]?.standardOutput ?? ""),
            software: parseSoftware(from: outputs["software"]?.standardOutput ?? ""),
            battery: parseBattery(powerJSON: outputs["power"]?.standardOutput ?? "", batteryIOReg: outputs["battery_ioreg"]?.combinedText ?? "", pmsetBattery: outputs["pmset_batt"]?.standardOutput ?? ""),
            storage: parseStorage(rootText: outputs["storage_root"]?.standardOutput ?? "", physicalText: outputs["storage_physical"]?.standardOutput ?? ""),
            nvme: parseNVMe(from: outputs["nvme"]?.standardOutput ?? ""),
            logs: parseLogs(
                pmsetLog: outputs["pmset_log"]?.standardOutput ?? "",
                panicReports: outputs["panic_reports"]?.standardOutput ?? "",
                structuredLogJSONLines: outputs["log_show"]?.standardOutput ?? ""
            ),
            peripherals: parsePeripherals(
                displaysJSON: outputs["displays"]?.standardOutput ?? "",
                wifiJSON: outputs["wifi"]?.standardOutput ?? "",
                bluetoothJSON: outputs["bluetooth"]?.standardOutput ?? "",
                cameraJSON: outputs["camera"]?.standardOutput ?? "",
                audioJSON: outputs["audio"]?.standardOutput ?? ""
            ),
            enrollment: parseEnrollment(from: outputs["profiles_enrollment"]?.combinedText ?? ""),
            deepMetrics: deepMetrics
        )
    }

    func collectPostStressSnapshot() throws -> PostStressSnapshot {
        TerminalProgressRenderer.stage(Presentation.progress("开始压测后复采", "Collecting post-stress samples", language: language))
        let powerOutput = try runner.run(["/usr/sbin/system_profiler", "SPPowerDataType", "-json"])
        _ = try persist(output: powerOutput, named: "power_post_stress")

        let batteryOutput = try runner.run(["/usr/sbin/ioreg", "-r", "-c", "AppleSmartBattery", "-l"])
        _ = try persist(output: batteryOutput, named: "battery_ioreg_post_stress")

        let pmsetOutput = try runner.run(["/usr/bin/pmset", "-g", "batt"])
        _ = try persist(output: pmsetOutput, named: "pmset_batt_post_stress")

        let rootOutput = try runner.run(["/usr/sbin/diskutil", "info", "-plist", "/"])
        _ = try persist(output: rootOutput, named: "storage_root_post_stress")

        var physicalText = ""
        if let physicalStore = parsePhysicalStoreIdentifier(from: rootOutput.standardOutput) {
            let physicalOutput = try runner.run(["/usr/sbin/diskutil", "info", "-plist", physicalStore])
            physicalText = physicalOutput.standardOutput
            _ = try persist(output: physicalOutput, named: "storage_physical_post_stress")
        }

        return PostStressSnapshot(
            battery: parseBattery(
                powerJSON: powerOutput.standardOutput,
                batteryIOReg: batteryOutput.combinedText,
                pmsetBattery: pmsetOutput.standardOutput
            ),
            storage: parseStorage(rootText: rootOutput.standardOutput, physicalText: physicalText)
        )
    }

    private func persist(output: CommandOutput, named name: String) throws -> CollectedCommand {
        let sanitized = name.replacingOccurrences(of: " ", with: "_")
        let outputFile = artifactsDirectory.appendingPathComponent("\(sanitized).txt")
        try output.standardOutput.write(to: outputFile, atomically: true, encoding: .utf8)

        var stderrFileName: String?
        if !output.standardError.isEmpty {
            let stderrURL = artifactsDirectory.appendingPathComponent("\(sanitized).stderr.txt")
            try output.standardError.write(to: stderrURL, atomically: true, encoding: .utf8)
            stderrFileName = stderrURL.lastPathComponent
        }

        return CollectedCommand(
            name: name,
            command: output.command,
            exitCode: output.exitCode,
            outputFile: outputFile.lastPathComponent,
            stderrFile: stderrFileName
        )
    }
}

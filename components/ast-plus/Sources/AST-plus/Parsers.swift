import Foundation

func parseJSON(_ text: String) -> Any? {
    guard let data = text.data(using: .utf8) else {
        return nil
    }
    return try? JSONSerialization.jsonObject(with: data)
}

func parsePlist(_ text: String) -> Any? {
    guard let data = text.data(using: .utf8) else {
        return nil
    }
    return try? PropertyListSerialization.propertyList(from: data, format: nil)
}

func parseHardware(from text: String) -> [String: String] {
    guard
        let root = parseJSON(text) as? [String: Any],
        let list = root["SPHardwareDataType"] as? [[String: Any]],
        let item = list.first
    else {
        return [:]
    }

    return [
        "machine_name": item["machine_name"] as? String,
        "machine_model": item["machine_model"] as? String,
        "model_number": item["model_number"] as? String,
        "chip_type": item["chip_type"] as? String,
        "physical_memory": item["physical_memory"] as? String,
        "serial_number": item["serial_number"] as? String,
        "boot_rom_version": item["boot_rom_version"] as? String,
        "activation_lock_status": item["activation_lock_status"] as? String
    ].compactMapValues { $0 }
}

func parseSoftware(from text: String) -> [String: String] {
    guard
        let root = parseJSON(text) as? [String: Any],
        let list = root["SPSoftwareDataType"] as? [[String: Any]],
        let item = list.first
    else {
        return [:]
    }

    return [
        "system_version": item["os_version"] as? String,
        "kernel_version": item["kernel_version"] as? String,
        "boot_mode": item["boot_mode"] as? String,
        "secure_vm": item["secure_vm"] as? String
    ].compactMapValues { $0 }
}

func parseBattery(powerJSON: String, batteryIOReg: String, pmsetBattery: String) -> BatterySnapshot {
    var cycleCount: Int?
    var designCycleCount: Int?
    var condition: String?
    var currentChargePercent: Double?
    var isCharging: Bool?
    var powerSource: String?
    var batterySerial: String?
    var designCapacityMah: Int?
    var nominalChargeCapacityMah: Int?

    if
        let root = parseJSON(powerJSON) as? [String: Any],
        let list = root["SPPowerDataType"] as? [[String: Any]]
    {
        if let batteryInfo = list.first(where: { ($0["_name"] as? String) == "spbattery_information" }) {
            if let chargeInfo = batteryInfo["sppower_battery_charge_info"] as? [String: Any] {
                currentChargePercent = intValue(chargeInfo["sppower_battery_state_of_charge"]).map(Double.init)
                if let chargingFlag = chargeInfo["sppower_battery_is_charging"] as? String {
                    isCharging = chargingFlag == "TRUE"
                }
            }
            if let healthInfo = batteryInfo["sppower_battery_health_info"] as? [String: Any] {
                cycleCount = intValue(healthInfo["sppower_battery_cycle_count"])
                condition = healthInfo["sppower_battery_health"] as? String
                if let maximumCapacity = healthInfo["sppower_battery_health_maximum_capacity"] as? String {
                    let sanitized = maximumCapacity.replacingOccurrences(of: "%", with: "")
                    if let value = Double(sanitized) {
                        return BatterySnapshot(
                            cycleCount: cycleCount,
                            designCycleCount: matchInt(in: batteryIOReg, pattern: "\"DesignCycleCount9C\" = (\\d+)"),
                            condition: condition,
                            maxCapacityPercent: value,
                            currentChargePercent: currentChargePercent,
                            isCharging: isCharging,
                            temperatureCelsius: matchDouble(in: batteryIOReg, pattern: "\"Temperature\" = (\\d+)").map { $0 / 100.0 },
                            powerSource: parsePowerSource(from: list, fallbackText: pmsetBattery),
                            designCapacityMah: matchInt(in: batteryIOReg, pattern: "\"DesignCapacity\" = (\\d+)"),
                            nominalChargeCapacityMah: matchInt(in: batteryIOReg, pattern: "\"NominalChargeCapacity\" = (\\d+)"),
                            batterySerial: matchString(in: batteryIOReg, pattern: "\"Serial\" = \"([^\"]+)\"")
                        )
                    }
                }
            }
        }
        powerSource = parsePowerSource(from: list, fallbackText: pmsetBattery)
    }

    let maxCapacity = matchDouble(in: batteryIOReg, pattern: "\"AppleRawMaxCapacity\" = (\\d+)")
        ?? matchDouble(in: batteryIOReg, pattern: "\"NominalChargeCapacity\" = (\\d+)")
    let designCapacity = matchDouble(in: batteryIOReg, pattern: "\"DesignCapacity\" = (\\d+)")
    let temperatureRaw = matchDouble(in: batteryIOReg, pattern: "\"Temperature\" = (\\d+)")
    let externalConnected = matchInt(in: batteryIOReg, pattern: "\"ExternalConnected\" = (\\d+)") == 1
    cycleCount = cycleCount ?? matchInt(in: batteryIOReg, pattern: "\"CycleCount\" = (\\d+)")
    designCycleCount = matchInt(in: batteryIOReg, pattern: "\"DesignCycleCount9C\" = (\\d+)")
    batterySerial = matchString(in: batteryIOReg, pattern: "\"Serial\" = \"([^\"]+)\"")
    designCapacityMah = matchInt(in: batteryIOReg, pattern: "\"DesignCapacity\" = (\\d+)")
    nominalChargeCapacityMah = matchInt(in: batteryIOReg, pattern: "\"NominalChargeCapacity\" = (\\d+)")

    if pmsetBattery.contains("charging") || pmsetBattery.contains("charged") {
        isCharging = true
    } else if pmsetBattery.contains("discharging") {
        isCharging = false
    }

    let maxCapacityPercent: Double?
    if let maxCapacity, let designCapacity, designCapacity > 0 {
        maxCapacityPercent = (maxCapacity / designCapacity) * 100.0
    } else {
        maxCapacityPercent = nil
    }

    return BatterySnapshot(
        cycleCount: cycleCount,
        designCycleCount: designCycleCount,
        condition: condition,
        maxCapacityPercent: maxCapacityPercent,
        currentChargePercent: currentChargePercent,
        isCharging: isCharging ?? (externalConnected ? true : nil),
        temperatureCelsius: temperatureRaw.map { $0 / 100.0 },
        powerSource: powerSource,
        designCapacityMah: designCapacityMah,
        nominalChargeCapacityMah: nominalChargeCapacityMah,
        batterySerial: batterySerial
    )
}

private func parsePowerSource(from powerItems: [[String: Any]], fallbackText: String) -> String {
    if powerItems.contains(where: { ($0["_name"] as? String) == "sppower_ac_charger_information" }) {
        return "AC"
    }
    if fallbackText.localizedCaseInsensitiveContains("Battery Power") {
        return "Battery"
    }
    return "unknown"
}

func parsePhysicalStoreIdentifier(from text: String) -> String? {
    guard let plist = parsePlist(text) as? [String: Any] else {
        return nil
    }

    if
        let stores = plist["APFSPhysicalStores"] as? [[String: Any]],
        let first = stores.first,
        let identifier = first["APFSPhysicalStore"] as? String
    {
        return identifier
    }

    if let identifier = plist["ParentWholeDisk"] as? String {
        return identifier
    }

    if (plist["WholeDisk"] as? Bool) == true {
        return plist["DeviceIdentifier"] as? String
    }

    return nil
}

func parseStorage(rootText: String, physicalText: String) -> StorageSnapshot {
    let root = parsePlist(rootText) as? [String: Any]
    let physical = parsePlist(physicalText) as? [String: Any]
    let preferred = physical ?? root ?? [:]
    let smartKeys = preferred["SMARTDeviceSpecificKeysMayVaryNotGuaranteed"] as? [String: Any]

    return StorageSnapshot(
        deviceIdentifier: preferred["DeviceIdentifier"] as? String ?? root?["DeviceIdentifier"] as? String,
        physicalStoreIdentifier: parsePhysicalStoreIdentifier(from: rootText),
        mediaName: preferred["MediaName"] as? String,
        totalSizeBytes: preferred["TotalSize"] as? Int64
            ?? (preferred["TotalSize"] as? NSNumber)?.int64Value
            ?? root?["TotalSize"] as? Int64
            ?? (root?["TotalSize"] as? NSNumber)?.int64Value,
        solidState: preferred["SolidState"] as? Bool ?? root?["SolidState"] as? Bool,
        smartStatus: preferred["SMARTStatus"] as? String ?? root?["SMARTStatus"] as? String,
        fileSystemName: root?["FilesystemName"] as? String ?? preferred["FilesystemName"] as? String,
        volumeName: root?["VolumeName"] as? String ?? preferred["VolumeName"] as? String,
        percentageUsed: intValue(smartKeys?["PERCENTAGE_USED"]),
        unsafeShutdowns: intValue(smartKeys?["UNSAFE_SHUTDOWNS_0"]),
        mediaErrors: intValue(smartKeys?["MEDIA_ERRORS_0"]),
        errorLogEntries: intValue(smartKeys?["NUM_ERROR_INFO_LOG_ENTRIES_0"]),
        temperatureCelsius: intValue(smartKeys?["TEMPERATURE"]).map { Double($0) / 10.0 }
    )
}

func parseLogs(pmsetLog: String, panicReports: String, structuredLogJSONLines: String) -> LogSnapshot {
    let reportLines = panicReports
        .split(separator: "\n")
        .map(String.init)
        .filter { !$0.isEmpty }

    let panicCount = reportLines.filter { line in
        let lowercased = line.lowercased()
        guard !lowercased.hasSuffix("/.contents.panic") else {
            return false
        }
        return lowercased.contains("/panic-") || lowercased.hasSuffix(".panic")
    }.count
    let gpuResetCount = reportLines.filter { $0.lowercased().contains("/gpuevent-") || $0.lowercased().contains("gpuevent-") }.count
    let ioErrorCount = pmsetLog.caseInsensitiveOccurrences(of: "failure")
        + pmsetLog.caseInsensitiveOccurrences(of: "i/o error")
    let shutdownEventCount = pmsetLog.caseInsensitiveOccurrences(of: "shutdown")
    let structuredSummary = parseStructuredLogSummary(from: structuredLogJSONLines)

    return LogSnapshot(
        panicCount: panicCount,
        ioErrorCount: ioErrorCount + structuredSummary.ioErrorCount,
        gpuResetCount: gpuResetCount + structuredSummary.gpuCount,
        shutdownEventCount: shutdownEventCount,
        previousShutdownCauseCount: structuredSummary.previousShutdownCauseCount,
        nvmeErrorCount: structuredSummary.nvmeCount,
        structuredLogEventCount: structuredSummary.totalEvents
    )
}

private func parseStructuredLogSummary(from text: String) -> StructuredLogSummary {
    let lines = text
        .split(separator: "\n")
        .map(String.init)
        .filter { $0.first == "{" }

    var summary = StructuredLogSummary()

    for line in lines {
        guard let object = parseJSON(line) as? [String: Any] else {
            continue
        }

        let eventMessage = (object["eventMessage"] as? String) ?? ""
        let composedMessage = (object["composedMessage"] as? String) ?? ""
        let combined = "\(eventMessage) \(composedMessage)".lowercased()

        summary.totalEvents += 1
        if combined.contains("previous shutdown cause") {
            summary.previousShutdownCauseCount += 1
        }
        if combined.contains("i/o error") {
            summary.ioErrorCount += 1
        }
        if combined.contains("nvme") {
            summary.nvmeCount += 1
        }
        if combined.contains("gpu") {
            summary.gpuCount += 1
        }
    }

    return summary
}

private struct StructuredLogSummary {
    var previousShutdownCauseCount = 0
    var ioErrorCount = 0
    var nvmeCount = 0
    var gpuCount = 0
    var totalEvents = 0
}

func parseNVMe(from text: String) -> NVMESnapshot {
    guard
        let root = parseJSON(text) as? [String: Any],
        let controllers = root["SPNVMeDataType"] as? [[String: Any]],
        let controller = controllers.first,
        let devices = controller["_items"] as? [[String: Any]],
        let device = devices.first
    else {
        return NVMESnapshot(
            controllerName: nil,
            deviceModel: nil,
            bsdName: nil,
            serial: nil,
            sizeBytes: nil,
            smartStatus: nil,
            trimSupport: nil
        )
    }

    return NVMESnapshot(
        controllerName: controller["_name"] as? String,
        deviceModel: device["device_model"] as? String ?? device["_name"] as? String,
        bsdName: device["bsd_name"] as? String,
        serial: device["device_serial"] as? String,
        sizeBytes: device["size_in_bytes"] as? Int64 ?? (device["size_in_bytes"] as? NSNumber)?.int64Value,
        smartStatus: device["smart_status"] as? String,
        trimSupport: device["spnvme_trim_support"] as? String
    )
}

func parsePeripherals(displaysJSON: String, wifiJSON: String, bluetoothJSON: String, cameraJSON: String, audioJSON: String) -> PeripheralSnapshot {
    let displayCount = countTopLevelItems(jsonText: displaysJSON, key: "SPDisplaysDataType")
    let wifiAvailable = countTopLevelItems(jsonText: wifiJSON, key: "SPAirPortDataType") > 0
    let bluetoothAvailable = countTopLevelItems(jsonText: bluetoothJSON, key: "SPBluetoothDataType") > 0
    let cameraAvailable = countTopLevelItems(jsonText: cameraJSON, key: "SPCameraDataType") > 0
    let audioDeviceCount = countTopLevelItems(jsonText: audioJSON, key: "SPAudioDataType")

    return PeripheralSnapshot(
        displayCount: displayCount,
        wifiAvailable: wifiAvailable,
        bluetoothAvailable: bluetoothAvailable,
        cameraAvailable: cameraAvailable,
        audioDeviceCount: audioDeviceCount
    )
}

func parseEnrollment(from text: String) -> EnrollmentSnapshot {
    let lowercased = text.lowercased()
    let depEnrolled: Bool?
    let mdmEnrolled: Bool?

    if lowercased.contains("enrolled via dep: yes") {
        depEnrolled = true
    } else if lowercased.contains("enrolled via dep: no") {
        depEnrolled = false
    } else {
        depEnrolled = nil
    }

    if lowercased.contains("mdm enrollment: yes") {
        mdmEnrolled = true
    } else if lowercased.contains("mdm enrollment: no") {
        mdmEnrolled = false
    } else {
        mdmEnrolled = nil
    }

    return EnrollmentSnapshot(depEnrolled: depEnrolled, mdmEnrolled: mdmEnrolled)
}

private func intValue(_ value: Any?) -> Int? {
    if let int = value as? Int {
        return int
    }
    if let string = value as? String {
        return Int(string.filter(\.isNumber))
    }
    if let number = value as? NSNumber {
        return number.intValue
    }
    return nil
}

private func doubleFromString(_ value: String?) -> Double? {
    guard let value else { return nil }
    let filtered = value.filter { $0.isNumber || $0 == "." }
    return Double(filtered)
}

private func matchDouble(in text: String, pattern: String) -> Double? {
    guard
        let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
        let range = Range(match.range(at: 1), in: text)
    else {
        return nil
    }

    return Double(text[range])
}

private func matchInt(in text: String, pattern: String) -> Int? {
    guard let value = matchDouble(in: text, pattern: pattern) else {
        return nil
    }
    return Int(value)
}

private func matchString(in text: String, pattern: String) -> String? {
    guard
        let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
        let range = Range(match.range(at: 1), in: text)
    else {
        return nil
    }

    return String(text[range])
}

private func countTopLevelItems(jsonText: String, key: String) -> Int {
    guard let root = parseJSON(jsonText) as? [String: Any] else {
        return 0
    }
    return (root[key] as? [Any])?.count ?? 0
}

private extension String {
    func caseInsensitiveOccurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }

        var count = 0
        var searchRange: Range<String.Index>? = startIndex..<endIndex

        while let range = range(of: needle, options: [.caseInsensitive], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<endIndex
        }

        return count
    }
}

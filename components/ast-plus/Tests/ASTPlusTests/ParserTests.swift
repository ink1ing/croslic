import XCTest
@testable import AST_plus

final class ParserTests: XCTestCase {
    func testParsePhysicalStoreIdentifierPrefersAPFSPhysicalStore() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>APFSPhysicalStores</key>
            <array>
                <dict>
                    <key>APFSPhysicalStore</key>
                    <string>disk0s2</string>
                </dict>
            </array>
            <key>DeviceIdentifier</key>
            <string>disk3s1s1</string>
        </dict>
        </plist>
        """

        XCTAssertEqual(parsePhysicalStoreIdentifier(from: plist), "disk0s2")
    }

    func testParseStorageUsesPhysicalDiskSmartMetrics() {
        let root = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>APFSPhysicalStores</key>
            <array>
                <dict>
                    <key>APFSPhysicalStore</key>
                    <string>disk0s2</string>
                </dict>
            </array>
            <key>DeviceIdentifier</key>
            <string>disk3s1s1</string>
            <key>FilesystemName</key>
            <string>APFS</string>
            <key>VolumeName</key>
            <string>Macintosh HD</string>
        </dict>
        </plist>
        """

        let physical = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>DeviceIdentifier</key>
            <string>disk0</string>
            <key>MediaName</key>
            <string>Apple SSD</string>
            <key>TotalSize</key>
            <integer>1000</integer>
            <key>SMARTStatus</key>
            <string>Verified</string>
            <key>SMARTDeviceSpecificKeysMayVaryNotGuaranteed</key>
            <dict>
                <key>PERCENTAGE_USED</key>
                <integer>3</integer>
                <key>UNSAFE_SHUTDOWNS_0</key>
                <integer>12</integer>
                <key>MEDIA_ERRORS_0</key>
                <integer>0</integer>
                <key>NUM_ERROR_INFO_LOG_ENTRIES_0</key>
                <integer>1</integer>
                <key>TEMPERATURE</key>
                <integer>301</integer>
            </dict>
        </dict>
        </plist>
        """

        let snapshot = parseStorage(rootText: root, physicalText: physical)

        XCTAssertEqual(snapshot.deviceIdentifier, "disk0")
        XCTAssertEqual(snapshot.physicalStoreIdentifier, "disk0s2")
        XCTAssertEqual(snapshot.fileSystemName, "APFS")
        XCTAssertEqual(snapshot.volumeName, "Macintosh HD")
        XCTAssertEqual(snapshot.percentageUsed, 3)
        XCTAssertEqual(snapshot.errorLogEntries, 1)
        XCTAssertNotNil(snapshot.temperatureCelsius)
        XCTAssertEqual(snapshot.temperatureCelsius ?? 0, 30.1, accuracy: 0.01)
    }

    func testParseLogsCountsDiagnosticFilesByType() {
        let reports = """
        /Library/Logs/DiagnosticReports/Retired/panic-full-2026-03-11-185037.0002.panic
        /Library/Logs/DiagnosticReports/Retired/gpuEvent-Python-2026-03-11-140331.ips
        /Library/Logs/DiagnosticReports/.contents.panic
        """

        let structured = """
        {"eventMessage":"Previous shutdown cause: -20"}
        {"composedMessage":"GPU restart detected"}
        {"eventMessage":"nvme timeout"}
        """

        let snapshot = parseLogs(pmsetLog: "I/O error\nfailure\nshutdown", panicReports: reports, structuredLogJSONLines: structured)

        XCTAssertEqual(snapshot.panicCount, 1)
        XCTAssertEqual(snapshot.gpuResetCount, 2)
        XCTAssertEqual(snapshot.ioErrorCount, 2)
        XCTAssertEqual(snapshot.shutdownEventCount, 1)
        XCTAssertEqual(snapshot.previousShutdownCauseCount, 1)
        XCTAssertEqual(snapshot.nvmeErrorCount, 1)
        XCTAssertEqual(snapshot.structuredLogEventCount, 3)
    }

    func testParseNVMeExtractsPrimaryDevice() {
        let json = """
        {
          "SPNVMeDataType" : [
            {
              "_items" : [
                {
                  "_name" : "APPLE SSD AP0512Z",
                  "bsd_name" : "disk0",
                  "device_model" : "APPLE SSD AP0512Z",
                  "device_serial" : "serial-123",
                  "size_in_bytes" : 500277792768,
                  "smart_status" : "Verified",
                  "spnvme_trim_support" : "Yes"
                }
              ],
              "_name" : "Apple SSD Controller"
            }
          ]
        }
        """

        let snapshot = parseNVMe(from: json)

        XCTAssertEqual(snapshot.controllerName, "Apple SSD Controller")
        XCTAssertEqual(snapshot.deviceModel, "APPLE SSD AP0512Z")
        XCTAssertEqual(snapshot.bsdName, "disk0")
        XCTAssertEqual(snapshot.serial, "serial-123")
        XCTAssertEqual(snapshot.smartStatus, "Verified")
        XCTAssertEqual(snapshot.trimSupport, "Yes")
    }
}

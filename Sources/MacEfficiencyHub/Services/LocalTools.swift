import Foundation

enum YTDLPFormat: String, CaseIterable, Identifiable {
    case mp3 = "MP3"
    case mp4 = "MP4"
    var id: String { rawValue }
}

struct MemoryMeter: Sendable {
    let usedFraction: Double
    let label: String
}

enum LocalTools {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    static func findExecutable(_ name: String) -> String? {
        let candidates = [
            home.appendingPathComponent(".local/bin/\(name)").path,
            "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func downloadWithYTDLP(url: String, outputDirectory: URL, format: YTDLPFormat) throws -> ProcessResult {
        guard let executable = findExecutable("yt-dlp") else { throw NSError(domain: "Hub", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到 yt-dlp"] ) }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let output = outputDirectory.appendingPathComponent("%(title)s.%(ext)s").path
        let arguments: [String]
        switch format {
        case .mp3:
            arguments = ["-f", "bv*+ba/b", "--extract-audio", "--audio-format", "mp3", "--audio-quality", "0", "-o", output, url]
        case .mp4:
            arguments = ["-f", "bv*+ba/b", "--merge-output-format", "mp4", "-o", output, url]
        }
        return try ProcessRunner.run(executable: executable, arguments: arguments, timeout: 600)
    }

    static func memoryMeter() -> MemoryMeter {
        guard let output = try? ProcessRunner.run(executable: "/usr/bin/vm_stat", arguments: [], timeout: 5).output else {
            return MemoryMeter(usedFraction: 0, label: "无法读取")
        }
        let pageSize = number(in: output, matching: "page size of ([0-9]+) bytes") ?? 4096
        let keys = ["Pages active", "Pages inactive", "Pages wired down", "Pages occupied by compressor"]
        let usedPages = keys.reduce(Int64(0)) { partial, key in
            partial + (number(in: output, matching: "\(key):\\s*([0-9]+)") ?? 0)
        }
        let usedBytes = Double(usedPages) * Double(pageSize)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let fraction = totalBytes > 0 ? min(max(usedBytes / totalBytes, 0), 1) : 0
        return MemoryMeter(usedFraction: fraction, label: "约 \(Int((fraction * 100).rounded()))%")
    }

    private static func number(in text: String, matching pattern: String) -> Int64? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int64(text[range])
    }

}

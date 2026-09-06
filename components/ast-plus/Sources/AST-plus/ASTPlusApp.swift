import Foundation

struct RunConfiguration {
    let mode: SessionMode
    let outputRoot: URL
    let stressSeconds: Int
    let skipStress: Bool
    let logWindow: String
    let language: OutputLanguage
    let detail: OutputDetail

    var deepMode: Bool {
        mode == .deep || mode == .auto
    }
}

struct RunArtifacts {
    let reportJSON: URL
    let reportMarkdown: URL
    let datedMarkdown: URL
    let checklist: URL
    let artifactsDirectory: URL
    let report: ASTPlusReport
}

struct ASTPlusApp {
    let configuration: CLIConfiguration

    func run() async throws {
        if configuration.interactive {
            try runInteractiveLoop()
            return
        }

        _ = try runScan(using: RunConfiguration(
            mode: configuration.sessionMode,
            outputRoot: configuration.outputRoot,
            stressSeconds: configuration.stressSeconds,
            skipStress: configuration.skipStress,
            logWindow: configuration.logWindow,
            language: configuration.language,
            detail: configuration.detail
        ))
    }

    func runScan(using runConfiguration: RunConfiguration) throws -> RunArtifacts {
        TerminalProgressRenderer.stage(Presentation.progress("准备输出目录", "Preparing output directories", language: runConfiguration.language))
        let fileManager = FileManager.default
        let reportsDirectory = runConfiguration.outputRoot.appendingPathComponent("reports", isDirectory: true)
        let artifactsDirectory = runConfiguration.outputRoot.appendingPathComponent("artifacts", isDirectory: true)

        try fileManager.createDirectory(at: runConfiguration.outputRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)

        let runner = CommandRunner()
        let collector = SystemCollector(
            runner: runner,
            artifactsDirectory: artifactsDirectory,
            deepMode: runConfiguration.deepMode,
            logWindow: runConfiguration.logWindow,
            language: runConfiguration.language
        )

        TerminalProgressRenderer.stage(Presentation.progress("开始系统采集", "Starting system collection", language: runConfiguration.language))
        let snapshot = try collector.collect()
        let stressSummary: StressSummary
        let postStressSnapshot: PostStressSnapshot?
        if runConfiguration.skipStress {
            TerminalProgressRenderer.stage(Presentation.progress("已跳过压测", "Stress test skipped", language: runConfiguration.language))
            stressSummary = StressSummary(
                durationSeconds: 0,
                workerCount: 0,
                iterations: 0,
                elapsedSeconds: 0,
                completed: false,
                skipped: true,
                memoryBytesTested: 0,
                memoryChecksum: nil,
                memoryPass: false
            )
            postStressSnapshot = nil
        } else {
            TerminalProgressRenderer.stage(Presentation.progress("开始 CPU / 内存压测", "Starting CPU / memory stress test", language: runConfiguration.language))
            stressSummary = try CPUStressTester(durationSeconds: runConfiguration.stressSeconds).run()
            postStressSnapshot = try collector.collectPostStressSnapshot()
        }

        TerminalProgressRenderer.stage(Presentation.progress("开始规则判断", "Evaluating collected data", language: runConfiguration.language))
        let evaluator = Evaluator(snapshot: snapshot, postStressSnapshot: postStressSnapshot, stressSummary: stressSummary)
        let report = evaluator.buildReport()

        let encoder = JSONEncoder()
        if #available(macOS 10.15, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let reportData = try encoder.encode(report)
        let reportJSON = reportsDirectory.appendingPathComponent("report.json")
        try reportData.write(to: reportJSON)

        TerminalProgressRenderer.stage(Presentation.progress("写入 Markdown / JSON 报告", "Writing Markdown / JSON reports", language: runConfiguration.language))
        let renderOptions = RenderOptions(language: runConfiguration.language, detail: runConfiguration.detail)
        let markdown = MarkdownReportRenderer.render(report: report, options: renderOptions)
        let reportMarkdown = reportsDirectory.appendingPathComponent("report.md")
        try markdown.write(to: reportMarkdown, atomically: true, encoding: .utf8)
        let datedMarkdown = runConfiguration.outputRoot.appendingPathComponent(Self.datedMarkdownName())
        try markdown.write(to: datedMarkdown, atomically: true, encoding: .utf8)

        let checklist = ManualChecklistRenderer.render(report: report, language: runConfiguration.language)
        let checklistURL = reportsDirectory.appendingPathComponent("manual_checklist.md")
        try checklist.write(to: checklistURL, atomically: true, encoding: .utf8)

        TerminalProgressRenderer.stage(Presentation.progress("检测完成，输出最终摘要", "Scan finished, rendering summary", language: runConfiguration.language))
        print(TerminalReportRenderer.render(report: report, options: renderOptions, datedMarkdown: datedMarkdown))
        print("JSON report: \(reportJSON.path)")
        print("Markdown report: \(reportMarkdown.path)")
        print("Dated Markdown: \(datedMarkdown.path)")
        print("Checklist: \(checklistURL.path)")
        print("Artifacts: \(artifactsDirectory.path)")
        if runConfiguration.deepMode, snapshot.deepMetrics.available == false {
            print("Deep mode note: \(snapshot.deepMetrics.note ?? "powermetrics unavailable")")
        }

        return RunArtifacts(
            reportJSON: reportJSON,
            reportMarkdown: reportMarkdown,
            datedMarkdown: datedMarkdown,
            checklist: checklistURL,
            artifactsDirectory: artifactsDirectory,
            report: report
        )
    }

    private static func datedMarkdownName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M.d.yy"
        return "\(formatter.string(from: Date())).md"
    }
}

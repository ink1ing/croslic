import Foundation

struct CommandOutput {
    let command: [String]
    let standardOutput: String
    let standardError: String
    let exitCode: Int32

    var combinedText: String {
        [standardOutput, standardError]
            .filter { !$0.isEmpty }
            .joined(separator: standardOutput.isEmpty || standardError.isEmpty ? "" : "\n")
    }
}

enum CommandRunnerError: Error {
    case invalidCommand
}

struct CommandRunner {
    func run(_ command: [String]) throws -> CommandOutput {
        guard let executable = command.first else {
            throw CommandRunnerError.invalidCommand
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CommandOutput(
            command: command,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}

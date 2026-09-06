import Foundation

@main
struct ASTPlus {
    static func main() async {
        do {
            let configuration = try CLIConfiguration(arguments: CommandLine.arguments)
            let app = ASTPlusApp(configuration: configuration)
            try await app.run()
        } catch let error as CLIConfigurationError {
            let isHelpRequest: Bool
            if case .helpRequested = error {
                isHelpRequest = true
            } else {
                isHelpRequest = false
            }
            let stream = isHelpRequest ? stdout : stderr
            fputs("\(error)\n", stream)
            exit(isHelpRequest ? 0 : 1)
        } catch {
            fputs("AST-plus failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

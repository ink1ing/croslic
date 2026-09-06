import CurrencyCore
import Foundation

@main
struct CurrencyCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 3, let amount = Decimal(string: args[0], locale: Locale(identifier: "en_US_POSIX")) else {
            print("用法: currency-converter <金额> <源币种> <目标币种> [--offline]")
            return
        }
        do {
            let result = try await CurrencyConverter().convert(
                amount: amount,
                from: args[1],
                to: args[2],
                offlineOnly: args.contains("--offline")
            )
            let value = NSDecimalNumber(decimal: result.convertedAmount).stringValue
            let source = result.snapshot.source == .live ? "实时汇率" : "内置离线汇率"
            print("\(result.amount) \(result.from) = \(value) \(result.to)（\(source)）")
        } catch {
            fputs("错误：\(error.localizedDescription)\n", stderr)
        }
    }
}

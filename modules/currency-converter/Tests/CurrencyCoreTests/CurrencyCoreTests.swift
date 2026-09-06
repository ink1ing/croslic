import XCTest
@testable import CurrencyCore

final class CurrencyCoreTests: XCTestCase {
    func testOfflineConversionUsesBundledRate() async throws {
        let result = try await CurrencyConverter().convert(amount: 100, from: "USD", to: "CNY", offlineOnly: true)
        XCTAssertEqual(result.snapshot.source, .bundledFallback)
        XCTAssertEqual(result.convertedAmount, 720)
    }

    func testInvalidCurrencyIsRejected() async {
        do {
            _ = try await CurrencyConverter().convert(amount: 1, from: "US", to: "CNY", offlineOnly: true)
            XCTFail("Expected invalid currency")
        } catch let error as CurrencyError {
            XCTAssertEqual(error, .invalidCurrency)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

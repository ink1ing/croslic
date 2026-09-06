import Foundation

public struct RateSnapshot: Codable, Sendable, Equatable {
    public let base: String
    public let quote: String
    public let rate: Decimal
    public let effectiveDate: String?
    public let source: Source
    public let fetchedAt: Date

    public enum Source: String, Codable, Sendable {
        case live
        case bundledFallback
    }

    public init(base: String, quote: String, rate: Decimal, effectiveDate: String?, source: Source, fetchedAt: Date = .now) {
        self.base = base
        self.quote = quote
        self.rate = rate
        self.effectiveDate = effectiveDate
        self.source = source
        self.fetchedAt = fetchedAt
    }
}

public struct ConversionResult: Sendable, Equatable {
    public let amount: Decimal
    public let from: String
    public let to: String
    public let convertedAmount: Decimal
    public let snapshot: RateSnapshot

    public init(amount: Decimal, from: String, to: String, convertedAmount: Decimal, snapshot: RateSnapshot) {
        self.amount = amount
        self.from = from
        self.to = to
        self.convertedAmount = convertedAmount
        self.snapshot = snapshot
    }
}

public enum CurrencyError: LocalizedError, Sendable, Equatable {
    case invalidCurrency
    case invalidAmount
    case unsupportedPair
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidCurrency: "币种代码必须是 3 位字母，例如 USD、CNY。"
        case .invalidAmount: "金额必须是有效的非负数字。"
        case .unsupportedPair: "当前没有可用的实时或离线汇率。"
        case .invalidResponse: "汇率服务返回了无法识别的数据。"
        }
    }
}

public protocol RateProvider: Sendable {
    func rate(from: String, to: String) async throws -> RateSnapshot
}

public struct FrankfurterRateProvider: RateProvider {
    private let session: URLSession
    private let host = "api.frankfurter.dev"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func rate(from: String, to: String) async throws -> RateSnapshot {
        let base = try CurrencyConverter.normalise(from)
        let quote = try CurrencyConverter.normalise(to)
        guard base != quote else {
            return RateSnapshot(base: base, quote: quote, rate: 1, effectiveDate: nil, source: .live)
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/v2/rate/\(base)/\(quote)"
        guard let url = components.url else { throw CurrencyError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CurrencyError.invalidResponse
        }
        let payload = try JSONDecoder().decode(FrankfurterRate.self, from: data)
        guard payload.rate.isFinite else { throw CurrencyError.invalidResponse }
        return RateSnapshot(base: base, quote: quote, rate: payload.rate, effectiveDate: payload.date, source: .live)
    }

    private struct FrankfurterRate: Decodable {
        let date: String?
        let rate: Decimal
    }
}

public actor CurrencyConverter {
    private let provider: any RateProvider
    private let cacheTTL: TimeInterval
    private var cache: [String: RateSnapshot] = [:]

    public init(provider: any RateProvider = FrankfurterRateProvider(), cacheTTL: TimeInterval = 3600) {
        self.provider = provider
        self.cacheTTL = cacheTTL
    }

    public func convert(amount: Decimal, from: String, to: String, offlineOnly: Bool = false) async throws -> ConversionResult {
        guard amount >= 0 else { throw CurrencyError.invalidAmount }
        let base = try Self.normalise(from)
        let quote = try Self.normalise(to)
        let snapshot: RateSnapshot
        if base == quote {
            snapshot = RateSnapshot(base: base, quote: quote, rate: 1, effectiveDate: nil, source: .bundledFallback)
        } else if !offlineOnly, let cached = cache[Self.key(base, quote)], Date.now.timeIntervalSince(cached.fetchedAt) < cacheTTL {
            snapshot = cached
        } else if !offlineOnly {
            do {
                let live = try await provider.rate(from: base, to: quote)
                cache[Self.key(base, quote)] = live
                snapshot = live
            } catch {
                snapshot = try Self.fallbackRate(from: base, to: quote)
            }
        } else {
            snapshot = try Self.fallbackRate(from: base, to: quote)
        }
        return ConversionResult(amount: amount, from: base, to: quote, convertedAmount: amount * snapshot.rate, snapshot: snapshot)
    }

    public func clearCache() {
        cache.removeAll()
    }

    public static func normalise(_ value: String) throws -> String {
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { throw CurrencyError.invalidCurrency }
        return code
    }

    private static func key(_ from: String, _ to: String) -> String { "\(from)->\(to)" }

    // Approximate bundled values, used only when offline or the live service is unavailable.
    private static let usdRates: [String: Decimal] = [
        "USD": 1, "CNY": 7.20, "EUR": 0.92, "JPY": 150, "GBP": 0.79,
        "HKD": 7.80, "TWD": 32.2, "KRW": 1380, "SGD": 1.34, "AUD": 1.53, "CAD": 1.36
    ]

    private static func fallbackRate(from: String, to: String) throws -> RateSnapshot {
        guard let fromRate = usdRates[from], let toRate = usdRates[to] else { throw CurrencyError.unsupportedPair }
        return RateSnapshot(base: from, quote: to, rate: toRate / fromRate, effectiveDate: nil, source: .bundledFallback)
    }
}

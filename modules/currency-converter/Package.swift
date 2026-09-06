// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CurrencyConverter",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CurrencyCore", targets: ["CurrencyCore"]),
        .executable(name: "currency-converter", targets: ["currency-converter"])
    ],
    targets: [
        .target(name: "CurrencyCore"),
        .executableTarget(name: "currency-converter", dependencies: ["CurrencyCore"]),
        .testTarget(name: "CurrencyCoreTests", dependencies: ["CurrencyCore"])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacEfficiencyHub",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacEfficiencyHub", targets: ["MacEfficiencyHub"])
    ],
    targets: [
        .executableTarget(
            name: "MacEfficiencyHub",
            path: "Sources/MacEfficiencyHub",
            linkerSettings: [
                .linkedFramework("SafariServices")
            ]
        ),
        .testTarget(
            name: "MacEfficiencyHubTests",
            dependencies: ["MacEfficiencyHub"],
            path: "Tests/MacEfficiencyHubTests"
        )
    ]
)

// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AST-plus",
    targets: [
        .executableTarget(
            name: "AST-plus"
        ),
        .testTarget(
            name: "ASTPlusTests",
            dependencies: [
                .target(name: "AST-plus")
            ]
        ),
    ]
)

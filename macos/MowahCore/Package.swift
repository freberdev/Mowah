// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MowahCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MowahCore", targets: ["MowahCore"]),
    ],
    targets: [
        .target(name: "MowahCore"),
        .testTarget(name: "MowahCoreTests", dependencies: ["MowahCore"]),
    ]
)

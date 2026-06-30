// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iBanana",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VaultCore"),
        .executableTarget(
            name: "iBanana",
            dependencies: ["VaultCore"]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"]
        ),
    ]
)

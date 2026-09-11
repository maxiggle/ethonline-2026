// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LedgerKeyring",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LedgerKeyring",
            targets: ["LedgerKeyring"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LedgerKeyring",
            dependencies: [],
            path: "Sources/LedgerKeyring"
        ),
        .testTarget(
            name: "LedgerKeyringTests",
            dependencies: ["LedgerKeyring"],
            path: "Tests/LedgerKeyringTests"
        ),
    ]
)

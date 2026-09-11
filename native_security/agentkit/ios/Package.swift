// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentKitSecurity",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AgentKitSecurity",
            targets: ["AgentKitSecurity"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AgentKitSecurity",
            dependencies: [],
            path: "Sources/AgentKitSecurity"
        ),
        .testTarget(
            name: "AgentKitSecurityTests",
            dependencies: ["AgentKitSecurity"],
            path: "Tests/AgentKitSecurityTests"
        ),
    ]
)

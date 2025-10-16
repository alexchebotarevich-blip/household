// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FamilyHub",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "FamilyHubCore",
            targets: ["FamilyHubCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FamilyHubCore",
            dependencies: []
        ),
        .testTarget(
            name: "FamilyHubCoreTests",
            dependencies: ["FamilyHubCore"]
        )
    ]
)

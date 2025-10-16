// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FamilyApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FamilyAppCore",
            targets: ["FamilyAppCore"]
        )
    ],
    targets: [
        .target(
            name: "FamilyAppCore",
            path: "Sources/FamilyAppCore"
        ),
        .testTarget(
            name: "FamilyAppTests",
            dependencies: ["FamilyAppCore"],
            path: "Tests/FamilyAppTests"
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FloatText",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "FloatText",
            path: "Sources/FloatText"
        ),
    ]
)

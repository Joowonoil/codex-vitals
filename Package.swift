// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexVitals",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "CodexVitals", path: "Sources/CodexVitals"),
        .testTarget(name: "CodexVitalsTests", dependencies: ["CodexVitals"])
    ]
)

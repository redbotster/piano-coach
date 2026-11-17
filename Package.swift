// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PianoCoach",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PianoCoach",
            path: "Sources/PianoCoach",
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        )
    ]
)

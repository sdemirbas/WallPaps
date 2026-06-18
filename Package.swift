// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WallPaps",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WallPaps",
            path: "Sources/WallPaps",
            swiftSettings: [
                // Pragmatic v5 concurrency to keep AppKit/Core Graphics interop friction-free.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

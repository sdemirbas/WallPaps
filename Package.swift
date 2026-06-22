// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WallPaps",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "WallPaps",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/WallPaps",
            swiftSettings: [
                // Pragmatic v5 concurrency to keep AppKit/Core Graphics interop friction-free.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

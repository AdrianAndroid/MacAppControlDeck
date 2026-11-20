// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MacAppControlDeck",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MacShotKit",
            path: "Sources/MacShotKit",
            swiftSettings: [.define("OFFLINE")],
            linkerSettings: [.linkedFramework("ScreenCaptureKit"), .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "ScreenCaptureKit"])]
        ),
        .executableTarget(
            name: "MacAppControlDeck",
            dependencies: ["MacShotKit"],
            path: "Sources/MacAppControlDeck"
        ),
        .executableTarget(
            name: "KeySender",
            path: "Sources/KeySender"
        ),
        .testTarget(
            name: "MacAppControlDeckTests",
            dependencies: ["MacAppControlDeck", "MacShotKit"],
            path: "Tests/MacAppControlDeckTests",
            linkerSettings: [.linkedFramework("ScreenCaptureKit"), .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "ScreenCaptureKit"])]
        )
    ]
)

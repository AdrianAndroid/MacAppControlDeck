// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MacAppControlDeck",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/6tail/lunar-swift.git", from: "1.1.9")
    ],
    targets: [
        .target(
            name: "MacShotKit",
            path: "Sources/MacShotKit",
            swiftSettings: [.define("OFFLINE")],
            linkerSettings: [.linkedFramework("ScreenCaptureKit"), .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "ScreenCaptureKit"])]
        ),
        .executableTarget(
            name: "MacAppControlDeck",
            dependencies: ["MacShotKit", .product(name: "LunarSwift", package: "lunar-swift")],
            path: "Sources/MacAppControlDeck",
            resources: [.copy("Modules/Sketch/Resources/Sketch"), .copy("Modules/Pet/Resources/v4")]
        ),
        .executableTarget(
            name: "KeySender",
            path: "Sources/KeySender"
        ),
        .testTarget(
            name: "MacAppControlDeckTests",
            dependencies: ["MacAppControlDeck", "MacShotKit", .product(name: "LunarSwift", package: "lunar-swift")],
            path: "Tests/MacAppControlDeckTests",
            linkerSettings: [.linkedFramework("ScreenCaptureKit"), .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "ScreenCaptureKit"])]
        )
    ]
)

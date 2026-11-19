// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MacAppControlDeck",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacAppControlDeck",
            path: "Sources/MacAppControlDeck"
        ),
        .executableTarget(
            name: "KeySender",
            path: "Sources/KeySender"
        ),
        .testTarget(
            name: "MacAppControlDeckTests",
            dependencies: ["MacAppControlDeck"],
            path: "Tests/MacAppControlDeckTests"
        )
    ]
)

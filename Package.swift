// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeadGesture",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "headgesture",
            targets: ["HeadGesture"]
        )
    ],
    targets: [
        .executableTarget(
            name: "HeadGesture",
            path: "Sources/HeadGesture"
        )
    ]
)

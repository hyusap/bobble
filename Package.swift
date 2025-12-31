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
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "HeadGesture",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/HeadGesture"
        )
    ]
)

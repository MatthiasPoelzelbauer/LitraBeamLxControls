// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LitraApp",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "LitraCore"),
        .executableTarget(name: "LitraApp", dependencies: ["LitraCore"]),
        .testTarget(name: "LitraCoreTests", dependencies: ["LitraCore"]),
    ]
)

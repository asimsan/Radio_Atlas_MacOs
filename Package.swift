// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RadioAtlas",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "RadioAtlasCore"),
        .executableTarget(
            name: "RadioAtlas",
            dependencies: ["RadioAtlasCore"]
        ),
        .testTarget(name: "RadioAtlasCoreTests", dependencies: ["RadioAtlasCore"])
    ]
)

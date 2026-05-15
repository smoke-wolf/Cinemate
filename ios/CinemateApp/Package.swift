// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CinemateApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "CinemateApp",
            path: "Sources/CinemateApp"
        )
    ]
)

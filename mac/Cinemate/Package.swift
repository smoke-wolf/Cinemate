// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cinemate",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
    ],
    targets: [
        .executableTarget(
            name: "Cinemate",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources/Cinemate",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/Cinemate.icns"),
                .copy("Resources/Assets.xcassets"),
            ]
        ),
    ]
)

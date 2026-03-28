// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DaibanCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "ObsidianParser", targets: ["ObsidianParser"]),
    ],
    targets: [
        .target(name: "ObsidianParser"),
        .testTarget(name: "ObsidianParserTests", dependencies: ["ObsidianParser"]),
    ]
)

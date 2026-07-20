// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AppFig",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "AppFig",
            targets: ["AppFig"]
        )
    ],
    targets: [
        .target(
            name: "AppFig",
            dependencies: [],
            path: "AppFig/AppFig",
            sources: ["."],
            publicHeadersPath: "."
        )
    ]
)

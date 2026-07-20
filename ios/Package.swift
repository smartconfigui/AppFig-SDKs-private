// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AppFigSDK",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "AppFigSDK",
            targets: ["AppFigSDK"]
        )
    ],
    targets: [
        .target(
            name: "AppFigSDK",
            dependencies: [],
            path: "AppFig/AppFig",
            sources: ["."],
            publicHeadersPath: "."
        )
    ]
)

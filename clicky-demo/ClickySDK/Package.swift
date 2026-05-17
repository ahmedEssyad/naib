// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClickySDK",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ClickySDK",
            targets: ["ClickySDK"]
        )
    ],
    targets: [
        .target(
            name: "ClickySDK",
            path: "Sources/ClickySDK"
        )
    ]
)

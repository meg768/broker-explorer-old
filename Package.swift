// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "mqtt-desktop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MQTTDesktop",
            targets: ["MQTTDesktop"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MQTTDesktop"
        )
    ]
)


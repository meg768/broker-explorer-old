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
    dependencies: [
        .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.13.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.80.0")
    ],
    targets: [
        .executableTarget(
            name: "MQTTDesktop",
            dependencies: [
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
        )
    ]
)

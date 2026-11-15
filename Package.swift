// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JARVISNova",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "JARVISNova", targets: ["JARVISNova"])
    ],
    dependencies: [
        .package(url: "https://github.com/nnabeyang/swift-msgpack.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "KeyFlowUI",
            dependencies: []
        ),
        .executableTarget(
            name: "JARVISNova",
            dependencies: [
                .product(name: "SwiftMsgpack", package: "swift-msgpack"),
                "KeyFlowUI"
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "JARVISNovaTests",
            dependencies: ["JARVISNova"]
        )
    ]
)
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZenPad",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ZenPad", targets: ["ZenPad"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ZenPad",
            path: "ZenPad",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources/Assets.xcassets")
            ],
            swiftSettings: [
                .unsafeFlags(["-O"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "ZenPadTests",
            dependencies: ["ZenPad"],
            path: "ZenPadTests"
        )
    ]
)

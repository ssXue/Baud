// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Baud",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Baud", targets: ["Baud"]),
        .library(name: "BaudKit", targets: ["BaudKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/armadsen/ORSSerialPort", from: "2.1.0"),
        .package(url: "https://github.com/ChartsOrg/Charts.git", from: "5.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Baud",
            dependencies: [
                "BaudKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Baud/App",
            exclude: ["Info.plist"],
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "BaudKit",
            dependencies: [
                .product(name: "ORSSerial", package: "ORSSerialPort"),
                .product(name: "DGCharts", package: "Charts"),
            ],
            path: "BaudKit",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "BaudKitTests",
            dependencies: ["BaudKit"],
            path: "Tests/BaudKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

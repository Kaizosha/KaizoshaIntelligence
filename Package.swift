// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KaizoshaIntelligence",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macCatalyst(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "KaizoshaIntelligence",
            targets: ["KaizoshaIntelligence"]
        ),
        .library(
            name: "KaizoshaProvider",
            targets: ["KaizoshaProvider"]
        ),
        .library(
            name: "KaizoshaOpenAI",
            targets: ["KaizoshaOpenAI"]
        ),
        .library(
            name: "KaizoshaAnthropic",
            targets: ["KaizoshaAnthropic"]
        ),
        .library(
            name: "KaizoshaGoogle",
            targets: ["KaizoshaGoogle"]
        ),
        .library(
            name: "KaizoshaGateway",
            targets: ["KaizoshaGateway"]
        ),
        .executable(
            name: "KaizoshaCLIExample",
            targets: ["KaizoshaCLIExample"]
        ),
        .executable(
            name: "KaizoshaServerExample",
            targets: ["KaizoshaServerExample"]
        ),
        .executable(
            name: "KaizoshaProviderComparisonExample",
            targets: ["KaizoshaProviderComparisonExample"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "KaizoshaProvider"
        ),
        .target(
            name: "KaizoshaTransport",
            dependencies: ["KaizoshaProvider"]
        ),
        .target(
            name: "KaizoshaIntelligence",
            dependencies: ["KaizoshaProvider"]
        ),
        .target(
            name: "KaizoshaOpenAI",
            dependencies: ["KaizoshaProvider", "KaizoshaTransport"]
        ),
        .target(
            name: "KaizoshaAnthropic",
            dependencies: ["KaizoshaProvider", "KaizoshaTransport"]
        ),
        .target(
            name: "KaizoshaGoogle",
            dependencies: ["KaizoshaProvider", "KaizoshaTransport"]
        ),
        .target(
            name: "KaizoshaGateway",
            dependencies: ["KaizoshaProvider", "KaizoshaTransport", "KaizoshaOpenAI"]
        ),
        .executableTarget(
            name: "KaizoshaCLIExample",
            dependencies: ["KaizoshaIntelligence", "KaizoshaOpenAI"],
            path: "Examples/CLIExample"
        ),
        .executableTarget(
            name: "KaizoshaServerExample",
            dependencies: ["KaizoshaIntelligence", "KaizoshaGateway"],
            path: "Examples/ServerExample"
        ),
        .executableTarget(
            name: "KaizoshaProviderComparisonExample",
            dependencies: [
                "KaizoshaIntelligence",
                "KaizoshaOpenAI",
                "KaizoshaAnthropic",
                "KaizoshaGoogle",
                "KaizoshaGateway",
            ]
            ,
            path: "Examples/ProviderComparisonExample"
        ),
        .testTarget(
            name: "KaizoshaSDKTests",
            dependencies: [
                "KaizoshaIntelligence",
                "KaizoshaProvider",
                "KaizoshaTransport",
                "KaizoshaOpenAI",
                "KaizoshaAnthropic",
                "KaizoshaGoogle",
                "KaizoshaGateway",
            ],
            path: "Tests/KaizoshaSDKTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

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
        .executable(
            name: "KaizoshaOpenAIResponsesExample",
            targets: ["KaizoshaOpenAIResponsesExample"]
        ),
        .executable(
            name: "KaizoshaOpenAIBuiltInToolsExample",
            targets: ["KaizoshaOpenAIBuiltInToolsExample"]
        ),
        .executable(
            name: "KaizoshaOpenAIRealtimeExample",
            targets: ["KaizoshaOpenAIRealtimeExample"]
        ),
        .executable(
            name: "KaizoshaGoogleGroundingExample",
            targets: ["KaizoshaGoogleGroundingExample"]
        ),
        .executable(
            name: "KaizoshaGoogleCachingExample",
            targets: ["KaizoshaGoogleCachingExample"]
        ),
        .executable(
            name: "KaizoshaGoogleFilesExample",
            targets: ["KaizoshaGoogleFilesExample"]
        ),
        .executable(
            name: "KaizoshaGoogleFileSearchExample",
            targets: ["KaizoshaGoogleFileSearchExample"]
        ),
        .executable(
            name: "KaizoshaGoogleBatchExample",
            targets: ["KaizoshaGoogleBatchExample"]
        ),
        .executable(
            name: "KaizoshaGoogleInteractionsExample",
            targets: ["KaizoshaGoogleInteractionsExample"]
        ),
        .executable(
            name: "KaizoshaGoogleLiveExample",
            targets: ["KaizoshaGoogleLiveExample"]
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
        .executableTarget(
            name: "KaizoshaOpenAIResponsesExample",
            dependencies: ["KaizoshaOpenAI"],
            path: "Examples/OpenAIResponsesExample"
        ),
        .executableTarget(
            name: "KaizoshaOpenAIBuiltInToolsExample",
            dependencies: ["KaizoshaOpenAI"],
            path: "Examples/OpenAIBuiltInToolsExample"
        ),
        .executableTarget(
            name: "KaizoshaOpenAIRealtimeExample",
            dependencies: ["KaizoshaOpenAI"],
            path: "Examples/OpenAIRealtimeExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleGroundingExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleGroundingExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleCachingExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleCachingExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleFilesExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleFilesExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleFileSearchExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleFileSearchExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleBatchExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleBatchExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleInteractionsExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleInteractionsExample"
        ),
        .executableTarget(
            name: "KaizoshaGoogleLiveExample",
            dependencies: ["KaizoshaGoogle"],
            path: "Examples/GoogleLiveExample"
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

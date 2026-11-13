// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wizit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Wizit", targets: ["Wizit"])
    ],
    targets: [
        .executableTarget(
            name: "Wizit",
            path: "Sources/Wizit",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .testTarget(
            name: "WizitTests",
            dependencies: ["Wizit"]
        )
    ]
)

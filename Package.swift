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
            ],
            linkerSettings: [
                // SwiftPM records the deployment target (14.0) as the linked SDK version, which makes
                // AppKit fall back to pre-Liquid-Glass controls. Record the macOS 27 SDK instead so
                // switches, sliders and segmented controls get the current system look.
                // The app still runs on macOS 14+.
                .unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "macos", "-Xlinker", "14.0", "-Xlinker", "27.0"])
            ]
        ),
        .testTarget(
            name: "WizitTests",
            dependencies: ["Wizit"]
        )
    ]
)

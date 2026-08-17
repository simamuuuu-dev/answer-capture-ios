// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AnswerCapture",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "AnswerCaptureCore",
            targets: ["AnswerCaptureCore"]
        )
    ],
    targets: [
        .target(
            name: "AnswerCaptureCore",
            path: "Sources/AnswerCaptureCore"
        ),
        .testTarget(
            name: "AnswerCaptureCoreTests",
            dependencies: ["AnswerCaptureCore"],
            path: "Tests/AnswerCaptureCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)

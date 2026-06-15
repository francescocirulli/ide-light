// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodeLightIDE",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodeLightIDE", targets: ["CodeLightIDE"])
    ],
    targets: [
        .executableTarget(
            name: "CodeLightIDE",
            path: "Sources/CodeLightIDE"
        )
    ]
)

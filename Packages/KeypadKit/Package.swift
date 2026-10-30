// swift-tools-version: 6.2
import PackageDescription

let strictSettings: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "KeypadKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KeypadCore", targets: ["KeypadCore"]),
        .library(name: "KeypadSystem", targets: ["KeypadSystem"]),
        .library(name: "KeypadUI", targets: ["KeypadUI"]),
    ],
    targets: [
        .target(name: "KeypadCore", swiftSettings: strictSettings),
        .target(
            name: "KeypadSystem",
            dependencies: ["KeypadCore"],
            resources: [.process("Resources")],
            swiftSettings: strictSettings
        ),
        .target(
            name: "KeypadUI",
            dependencies: ["KeypadCore"],
            resources: [.process("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(name: "KeypadCoreTests", dependencies: ["KeypadCore"], swiftSettings: strictSettings),
        .testTarget(name: "KeypadSystemTests", dependencies: ["KeypadSystem"], swiftSettings: strictSettings),
        .testTarget(name: "KeypadUITests", dependencies: ["KeypadUI", "KeypadCore"], swiftSettings: strictSettings),
    ]
)

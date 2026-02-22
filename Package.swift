// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MailAssistantService",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MailAssistant", targets: ["MailAssistant"]),
        .library(name: "PluginAPI", targets: ["PluginAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .target(
            name: "PluginAPI",
            dependencies: [],
            path: "PluginAPI/Sources"
        ),
        .executableTarget(
            name: "MailAssistant",
            dependencies: [
                "PluginAPI",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "MailAssistant/Sources"
        ),
    ]
)

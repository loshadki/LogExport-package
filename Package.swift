// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "LogExport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LogExport",
            targets: ["LogExport"]),
    ],
    targets: [
        .target(
            name: "LogExport"),
    ],
    swiftLanguageVersions: [.v5]
)

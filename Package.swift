// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterI18n",
    platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v8), .tvOS(.v15)],
    products: [
        .library(name: "BetterI18n", targets: ["BetterI18n"]),
        .library(name: "BetterI18nUI", targets: ["BetterI18nUI"]),
    ],
    targets: [
        .target(name: "BetterI18n"),
        .target(name: "BetterI18nUI", dependencies: ["BetterI18n"]),
        .testTarget(name: "BetterI18nTests", dependencies: ["BetterI18n"]),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AllegeCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AllegeCore", targets: ["AllegeCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "AllegeCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        // Harnais de tests : XCTest et Swift Testing ne sont pas livres avec
        // les Command Line Tools (voir docs/tests.md).
        .executableTarget(
            name: "allegecore-check",
            dependencies: ["AllegeCore"]
        ),
    ]
)

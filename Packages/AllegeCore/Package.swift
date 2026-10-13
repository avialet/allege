// swift-tools-version: 6.0
import PackageDescription

// Noyau sans interface : formats, prereglages, traitement ImageIO.
// Allege n'a pas de base de donnees : rien n'est conserve entre deux lancements.
let package = Package(
    name: "AllegeCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AllegeCore", targets: ["AllegeCore"]),
    ],
    targets: [
        .target(name: "AllegeCore"),
        // Harnais de tests : XCTest et Swift Testing ne sont pas livres avec
        // les Command Line Tools (voir docs/tests.md).
        .executableTarget(name: "allegecore-check", dependencies: ["AllegeCore"]),
    ]
)

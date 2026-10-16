// swift-tools-version:5.9
// Пакет нужен только для запуска unit-тестов чистой логики (`swift test` на macOS).
// Приложение собирается через VPNClient.xcodeproj.
import PackageDescription

let package = Package(
    name: "VPNClientLogic",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "VPNClientLogic", targets: ["VPNClientLogic"]),
    ],
    targets: [
        .target(
            name: "VPNClientLogic",
            path: ".",
            sources: ["Shared", "VPNClient/ProfileStore.swift"]
        ),
        .testTarget(
            name: "VPNClientLogicTests",
            dependencies: ["VPNClientLogic"],
            path: "Tests/VPNClientLogicTests"
        ),
    ]
)

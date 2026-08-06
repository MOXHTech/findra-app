// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FindraApp",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Findra", targets: ["FindraApp"])
    ],
    targets: [
        .executableTarget(
            name: "FindraApp",
            path: "Sources/FindraApp"
        ),
        .testTarget(
            name: "FindraAppTests",
            dependencies: ["FindraApp"],
            path: "Tests/FindraAppTests"
        )
    ]
)

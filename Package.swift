// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppContextKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "AppContextKit", targets: ["AppContextKit"]),
    ],
    targets: [
        .target(name: "AppContextKit"),
        .testTarget(
            name: "AppContextKitTests",
            dependencies: ["AppContextKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

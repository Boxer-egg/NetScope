// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NetScope",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetScope", targets: ["NetScope"])
    ],
    dependencies: [
        .package(url: "https://github.com/zpzlabs/maxminddb-swift.git", revision: "e308871390b0e16cab72de7ff28b9284ee11daf0")
    ],
    targets: [
        .executableTarget(
            name: "NetScope",
            dependencies: [
                .product(name: "MaxMindDB", package: "maxminddb-swift")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NetScopeTests",
            dependencies: ["NetScope"]
        )
    ]
)

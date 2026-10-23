// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NumberBindingKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "NumberBindingKit", targets: ["NumberBindingKit"]),
        .executable(name: "NumberBindingDemo", targets: ["NumberBindingDemo"])
    ],
    targets: [
        .target(name: "NumberBindingKit"),
        .executableTarget(
            name: "NumberBindingDemo",
            dependencies: ["NumberBindingKit"]
        ),
        .testTarget(
            name: "NumberBindingKitTests",
            dependencies: ["NumberBindingKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)

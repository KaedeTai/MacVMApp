// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacVMApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacVMApp", targets: ["MacVMApp"])
    ],
    targets: [
        .executableTarget(
            name: "MacVMApp",
            path: "Sources"
        )
    ]
)

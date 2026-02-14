// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacVMAppGUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacVMAppGUI", targets: ["MacVMAppGUI"])
    ],
    targets: [
        .executableTarget(
            name: "MacVMAppGUI",
            path: "Sources",
            exclude: ["Info.plist"]
        )
    ]
)

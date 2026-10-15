// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WakeBee",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WakeBee", targets: ["WakeBee"]),
               .executable(name: "WakeBeeHelper", targets: ["WakeBeeHelper"])],
    targets: [
        .target(name: "WakeBeeCore"),
        .target(name: "WakeBeeHelperProtocol"),
        .executableTarget(name: "WakeBeeHelper", dependencies: ["WakeBeeCore", "WakeBeeHelperProtocol"]),
        .executableTarget(
            name: "WakeBee",
            dependencies: ["WakeBeeCore", "WakeBeeHelperProtocol"]
        ),
        .testTarget(name: "WakeBeeCoreTests", dependencies: ["WakeBeeCore"]),
        .testTarget(name: "WakeBeeTests", dependencies: ["WakeBee"])
    ]
)

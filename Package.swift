// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AsunSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    products: [
        .library(name: "AsunSwift", targets: ["AsunSwift"])
    ],
    targets: [
        .target(name: "AsunSwift"),
        .executableTarget(name: "basic", dependencies: ["AsunSwift"], path: "Examples/basic"),
        .executableTarget(name: "complex", dependencies: ["AsunSwift"], path: "Examples/complex"),
        .executableTarget(name: "cross_compat", dependencies: ["AsunSwift"], path: "Examples/cross_compat"),
        .executableTarget(name: "bench", dependencies: ["AsunSwift"], path: "Examples/bench"),
        .executableTarget(name: "debug", dependencies: ["AsunSwift"], path: "Examples/debug"),
        .executableTarget(name: "run_tests", dependencies: ["AsunSwift"], path: "Tests/AsunSwiftTests")
    ]
)

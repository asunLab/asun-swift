// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AsonSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    products: [
        .library(name: "AsonSwift", targets: ["AsonSwift"])
    ],
    targets: [
        .target(name: "AsonSwift"),
        .executableTarget(name: "basic", dependencies: ["AsonSwift"], path: "Examples/basic"),
        .executableTarget(name: "complex", dependencies: ["AsonSwift"], path: "Examples/complex"),
        .executableTarget(name: "cross_compat", dependencies: ["AsonSwift"], path: "Examples/cross_compat"),
        .executableTarget(name: "bench", dependencies: ["AsonSwift"], path: "Examples/bench"),
        .executableTarget(name: "debug", dependencies: ["AsonSwift"], path: "Examples/debug"),
        .executableTarget(name: "run_tests", dependencies: ["AsonSwift"], path: "Tests/AsonSwiftTests")
    ]
)

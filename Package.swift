// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "SwiftCompilationTimingParser",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwiftCompilationTimingParser", targets: ["SwiftCompilationTimingParser"]),
        .library(name: "SwiftCompilationTimingParserFramework", targets: ["SwiftCompilationTimingParserFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/MobileNativeFoundation/XCLogParser", exact: "0.2.36"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftCompilationTimingParser",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XCLogParser", package: "XCLogParser"),
                "SwiftCompilationTimingParserFramework"
            ],
            path: "Sources/SwiftCompilationTimingParser",
            swiftSettings: [.define("DEBUG", .when(configuration: .debug))]),
        .target(
            name: "SwiftCompilationTimingParserFramework",
            dependencies: [
                .product(name: "XCLogParser", package: "XCLogParser"),
            ],
            path: "Sources/SwiftCompilationTimingParserFramework"
        ),
        .testTarget(
            name: "SwiftCompilationTimingParserTests",
            dependencies: [
                "SwiftCompilationTimingParser",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XCLogParser", package: "XCLogParser"),
            ]
        ),
    ]
)

for target in package.targets {
 target.swiftSettings = target.swiftSettings ?? []
 target.swiftSettings?.append(
   .unsafeFlags([
     "-enable-bare-slash-regex",
   ])
 )
}

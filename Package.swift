// swift-tools-version: 6.2
import PackageDescription
import Foundation

let cblstTarget: Target
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    cblstTarget = .binaryTarget(
        name: "CBlst",
        path: "CBlst.xcframework"
    )
#elseif os(Linux)
    cblstTarget = .binaryTarget(
        name: "CBlst",
        path: "CBlst.artifactbundle"
    )
#else
    cblstTarget = .systemLibrary(
        name: "CBlst",
        path: "CBlst",
        pkgConfig: "blst",
        providers: [
            .apt(["libblst-dev"]),
            .brew(["blst"]),
        ]
    )
#endif

let package = Package(
    name: "swift-blst",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
    ],
    products: [
        .library(name: "CBlst", targets: ["CBlst"]),
        .library(name: "SwiftBLST", targets: ["SwiftBLST"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMinor(from: "5.3.0")),
    ],
    targets: [
        cblstTarget,
        .target(
            name: "SwiftBLST",
            dependencies: [
                "CBlst",
                .product(name: "BigInt", package: "BigInt"),
            ],
            path: "Sources/SwiftBLST",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftBLSTTests",
            dependencies: ["SwiftBLST"],
            path: "Tests/SwiftBLSTTests",
            resources: [.copy("Vectors")]
        ),
    ]
)
